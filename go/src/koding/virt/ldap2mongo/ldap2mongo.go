package main

import (
	"fmt"
	"koding/tools/db"
	"koding/tools/utils"
	"koding/virt"
	"labix.org/v2/mgo/bson"
	"os/user"
	"strconv"
)

func main() {
	utils.Startup("ldap2mongodb", false)

	iter := db.Users.Find(nil).Iter()
	var mongoUser virt.User
	for iter.Next(&mongoUser) {
		sysUser, err := user.Lookup(mongoUser.Name)
		if err != nil {
			fmt.Println(mongoUser.Name, err.Error())
			continue
		}
		uid, _ := strconv.Atoi(sysUser.Uid)
		db.Users.UpdateId(mongoUser.ObjectId, bson.M{"$set": bson.M{"uid": uid}})
	}
	if iter.Err() != nil {
		panic(iter.Err())
	}
}
