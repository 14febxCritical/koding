package mongodb

import (
	"fmt"
	"koding/tools/config"
	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
	"os"
	"sync"
)

type MongoDB struct {
	Session *mgo.Session
	URL     string
}

var (
	Mongo *MongoDB
	mu    sync.Mutex
)

func init() {
	Mongo = NewMongoDB(config.Current.Mongo)
}

func NewMongoDB(url string) *MongoDB {
	m := &MongoDB{
		URL: url,
	}

	m.CreateSession(m.URL)
	return m
}

func ChangeURL(url string) {
	mu.Lock()
	defer mu.Unlock()

	Mongo.Session = nil
	Mongo.URL = url
}

func (m *MongoDB) CreateSession(url string) {
	var err error
	m.Session, err = mgo.Dial(url)
	if err != nil {
		fmt.Printf("mongodb connection error: %s/n", err)
		os.Exit(1)
		return
	}

	m.Session.SetSafe(&mgo.Safe{})
}

func (m *MongoDB) Close() {
	m.Session.Close()
}

func (m *MongoDB) Refresh() {
	m.Session.Refresh()
}

func (m *MongoDB) Copy() *mgo.Session {
	return m.Session.Copy()
}

func (m *MongoDB) GetSession() *mgo.Session {
	if m.Session == nil {
		m.CreateSession(m.URL)
	}
	return m.Copy()
}

func (m *MongoDB) Run(collection string, s func(*mgo.Collection) error) error {
	session := m.GetSession()
	defer session.Close()
	c := session.DB("").C(collection)
	return s(c)
}

// RunOnDatabase runs command on given database, instead of current database
// this is needed for kite datastores currently, since it uses another database
// on the same connection. mongodb has database level write lock, which locks
// the entire database while flushing data, if kites tend to send too many
// set/get/delete commands this wont lock our koding database - hopefully
func RunOnDatabase(database string, collection string, s func(*mgo.Collection) error) error {
	session := Mongo.GetSession()
	defer session.Close()
	c := session.DB(database).C(collection)
	return s(c)
}

func Run(collection string, s func(*mgo.Collection) error) error {
	session := Mongo.GetSession()
	defer session.Close()
	c := session.DB("").C(collection)
	return s(c)
}

func One(collection, id string, result interface{}) error {
	session := Mongo.GetSession()
	defer session.Close()
	return session.DB("").C(collection).FindId(bson.ObjectIdHex(id)).One(result)
}
