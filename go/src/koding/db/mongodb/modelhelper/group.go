package modelhelper

import (
	"koding/db/models"
	"koding/db/mongodb"
	"labix.org/v2/mgo"
)

func GetGroup(groupname string) (*models.Group, error) {
	group := new(models.Group)

	query := func(c *mgo.Collection) error {
		return c.Find(Selector{"title": groupname}).One(&group)
	}

	return group, mongodb.Run("jGroups", query)
}

func CheckGroupExistence(groupname string) (bool, error) {
	var count int
	query := func(c *mgo.Collection) error {
		var err error
		count, err = c.Find(Selector{"slug": groupname}).Count()
		if err != nil {
			return err
		}
		return nil
	}

	return count > 0, mongodb.Run("jGroups", query)
}
