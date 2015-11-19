package softlayer

import (
	"koding/db/models"
	"koding/kites/kloud/plans"
	"time"

	"koding/kites/kloud/contexthelper/session"

	"github.com/koding/logging"
	"labix.org/v2/mgo/bson"
)

// Machine represents a single MongodDB document from the jMachines
// collection.
type Machine struct {
	Id          bson.ObjectId `bson:"_id" json:"-"`
	Label       string        `bson:"label"`
	Domain      string        `bson:"domain"`
	QueryString string        `bson:"queryString"`
	IpAddress   string        `bson:"ipAddress"`
	Assignee    struct {
		InProgress bool      `bson:"inProgress"`
		AssignedAt time.Time `bson:"assignedAt"`
	} `bson:"assignee"`
	Status struct {
		State      string    `bson:"state"`
		Reason     string    `bson:"reason"`
		ModifiedAt time.Time `bson:"modifiedAt"`
	} `bson:"status"`
	Provider   string    `bson:"provider"`
	Credential string    `bson:"credential"`
	CreatedAt  time.Time `bson:"createdAt"`
	Meta       struct {
		AlwaysOn bool   `bson:"alwaysOn"`
		Region   string `structs:"region" bson:"region"`
	} `bson:"meta"`
	Users  []models.Permissions `bson:"users"`
	Groups []models.Permissions `bson:"groups"`

	// internal fields, not availabile in MongoDB schema
	Username string                 `bson:"-"`
	User     *models.User           `bson:"-"`
	Payment  *plans.PaymentResponse `bson:"-"`
	Checker  plans.Checker          `bson:"-"`
	Session  *session.Session       `bson:"-"`
	Log      logging.Logger         `bson:"-"`

	// cleanFuncs are a list of functions that are called when after a method
	// is finished
	cleanFuncs []func()
}
