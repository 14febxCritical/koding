package db

import (
	"koding/tools/config"
	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
)

type Counter struct {
	Name  string `bson:"_id"`
	Value int    `bson:"seq"`
}

var database *mgo.Database

var counters *mgo.Collection
var Accounts *mgo.Collection
var Domains *mgo.Collection
var Users *mgo.Collection
var VMs *mgo.Collection

func init() {
	session, err := mgo.Dial(config.Current.Mongo)
	if err != nil {
		panic(err)
	}
	session.SetSafe(&mgo.Safe{})
	database = session.DB("")
	counters = database.C("counters")
	Accounts = database.C("jAccounts")
	Domains = database.C("jDomains")
	Users = database.C("jUsers")
	VMs = database.C("jVMs")
}

// may panic
func NextCounterValue(counterName string, initialValue int) int {
	var c Counter
	if _, err := counters.FindId(counterName).Apply(mgo.Change{Update: bson.M{"$inc": bson.M{"seq": 1}}}, &c); err != nil {
		if err == mgo.ErrNotFound {
			counters.Insert(Counter{Name: counterName, Value: initialValue}) // ignore error and try to do atomic update again
			if _, err := counters.FindId(counterName).Apply(mgo.Change{Update: bson.M{"$inc": bson.M{"seq": 1}}}, &c); err != nil {
				panic(err)
			}
			return c.Value
		}
		panic(err)
	}
	return c.Value
}
