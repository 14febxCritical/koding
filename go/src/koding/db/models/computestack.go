package models

import (
	"koding/kites/kloud/stackstate"
	"time"

	"labix.org/v2/mgo/bson"
)

// ComputeStack is a document from jComputeStack collection
type ComputeStack struct {
	Id       bson.ObjectId   `bson:"_id" json:"-"`
	Machines []bson.ObjectId `bson:"machines"`

	// Points to a document in jStackTemplates
	BaseStackId bson.ObjectId `bson:"baseStackId"`

	// User injected credentials
	Credentials map[string][]string `bson:"credentials"`

	Status struct {
		State     string    `bson:"state"`
		Reason    string    `bson:"reason"`
		UpdatedAt time.Time `bson:"updatedAt"`
	} `bson:"status"`
}

func (c *ComputeStack) State() stackstate.State {
	return stackstate.States[c.Status.State]
}
