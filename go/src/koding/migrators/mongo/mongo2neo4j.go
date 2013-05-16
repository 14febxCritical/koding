package main

import (
	"fmt"
	"koding/databases/mongo"
	"koding/databases/neo4j"
	"koding/tools/config"
	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
	"strings"
	"time"
)

type Relationship struct {
	TargetId   bson.ObjectId `bson:"targetId,omitempty"`
	TargetName string        `bson:"targetName"`
	SourceId   bson.ObjectId `bson:"sourceId,omitempty"`
	SourceName string        `bson:"sourceName"`
	As         string
	Data       bson.Binary
	Timestamp  time.Time `bson:"timestamp"`
}

var (
	SAVED_DATA            = make(map[string]interface{})
	MONGO_CONNECTION      *mgo.Session
	MONGO_CONN_STRING     = config.Current.Mongo
	MONGO_COLLECTION_NAME = "relationships"
)

func main() {

	if MONGO_CONNECTION == nil {
		// connnect to mongo
		var err error
		fmt.Println(MONGO_CONN_STRING)
		MONGO_CONNECTION, err = mgo.Dial(MONGO_CONN_STRING)
		if err != nil {
			fmt.Println(err)
		}
	}

	defer MONGO_CONNECTION.Close()

	neo4j.CreateUniqueIndex("koding")

	relationshipColl := MONGO_CONNECTION.DB("").C(MONGO_COLLECTION_NAME)

	// we need to iterate all over the table, fetching all documents is not a clear way!
	//this is cool
	var result *Relationship

	i := 0
	skip := 0 //25812 + 27752 + 54945
	iter := relationshipColl.Find(nil).Skip(skip).Limit(0).Sort("-timestamp").Iter()

	//iterate over results
	for iter.Next(&result) {
		i += 1
		fmt.Println(i)

		if result.SourceName == "" || result.TargetName == "" {
			continue
		}

		if !checkIfEligible(result.SourceName, result.TargetName) {
			continue
		}

		hexSourceId := result.SourceId.Hex()
		hexTargetId := result.TargetId.Hex()

		sourceContent := getContent(result.SourceId, result.SourceName)
		targetContent := getContent(result.TargetId, result.TargetName)

		if sourceContent == "" || targetContent == "" {
			continue
		}

		sourceNode := neo4j.CreateUniqueNode(hexSourceId, result.SourceName)
		targetNode := neo4j.CreateUniqueNode(hexTargetId, result.TargetName)
		source := fmt.Sprintf("%s", sourceNode["create_relationship"])
		target := fmt.Sprintf("%s", targetNode["self"])

		//UTC for date time uniqueness
		//format is a Go woodoo :)
		createdAt := result.Timestamp.UTC()
		relationshipData := fmt.Sprintf(`{"createdAt" : "%s", "createdAtEpoch" : %d }`, createdAt.Format("2006-01-02T15:04:05.000Z"), createdAt.Unix())
		neo4j.CreateRelationshipWithData(result.As, source, target, relationshipData)

		if _, ok := SAVED_DATA[hexSourceId]; !ok {
			neo4j.UpdateNode(hexSourceId, sourceContent)
			SAVED_DATA[hexSourceId] = sourceContent
		}

		if _, ok := SAVED_DATA[hexTargetId]; !ok {
			neo4j.UpdateNode(hexTargetId, targetContent)
			SAVED_DATA[hexTargetId] = targetContent
		}

	}

	if iter.Err() != nil {
		fmt.Println("err during iteration", iter.Err())
	}

	fmt.Println("Migration completed")
}

func getContent(objectId bson.ObjectId, name string) string {

	hexId := objectId.Hex()
	content := ""
	var err error
	if _, ok := SAVED_DATA[hexId]; ok {
		content = fmt.Sprintf("%s", SAVED_DATA[hexId])
	} else {
		content, err = mongo.FetchContent(objectId, name)
		if err != nil {
			fmt.Println("source err ", err)
			content = ""
		}
	}

	return content
}

func checkIfEligible(sourceName, targetName string) bool {

	fmt.Println(sourceName)
	fmt.Println(targetName)
	notAllowedNames := []string{
		"CStatusActivity",
		"CFolloweeBucketActivity",
		"CFollowerBucketActivity",
		"CCodeSnipActivity",
		"CDiscussionActivity",
		"CReplieeBucketActivity",
		"CReplierBucketActivity",
		"CBlogPostActivity",
		"CNewMemberBucketActivity",
		"CTutorialActivity",
		"CLikeeBucketActivity",
		"CLikerBucketActivity",
		"CInstalleeBucketActivity",
		"CInstallerBucketActivity",
		"CActivity",
		"CRunnableActivity",
		"JAppStorage",
		"JFeed",
	}
	notAllowedSuffixes := []string{
		"Bucket",
		"BucketActivity",
	}

	for _, name := range notAllowedNames {
		if name == sourceName {
			fmt.Println("not eligible " + sourceName)
			return false
		}

		if name == targetName {
			fmt.Println("not eligible " + targetName)
			return false
		}
	}

	for _, name := range notAllowedSuffixes {

		if strings.HasSuffix(sourceName, name) {
			fmt.Println("not eligible " + sourceName)
			return false
		}

		if strings.HasSuffix(targetName, name) {
			fmt.Println("not eligible " + targetName)
			return false
		}

	}

	if strings.HasSuffix(sourceName, "Bucket") || strings.HasSuffix(targetName, "Bucket") || strings.HasSuffix(sourceName, "BucketActivity") || strings.HasSuffix(targetName, "BucketActivity") {
		fmt.Println("not eligible " + sourceName + " " + targetName)
		return false
	}
	return true
}
