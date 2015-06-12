package webhook

import (
	"socialapi/models"
	"testing"

	"github.com/koding/runner"
	. "github.com/smartystreets/goconvey/convey"
)

func TestChannelIntegrationCreate(t *testing.T) {
	r := runner.New("test")
	if err := r.Init(); err != nil {
		t.Fatalf("couldnt start bongo %s", err)
	}
	defer r.Close()

	account := createTestAccount(t)

	channel := createTestGroupChannel(t, account)

	integration := CreateTestIntegration(t)

	Convey("while creating a channel integration", t, func() {
		i := NewChannelIntegration()
		i.CreatorId = account.Id
		i.ChannelId = channel.Id
		err := i.Create()
		So(err, ShouldEqual, models.ErrGroupNameIsNotSet)

		i.IntegrationId = integration.Id
		i.GroupName = models.RandomGroupName()
		i.ChannelId = 0
		err = i.Create()
		So(err, ShouldEqual, models.ErrChannelIsNotSet)

		i.ChannelId = channel.Id
		i.CreatorId = 0
		err = i.Create()
		So(err, ShouldEqual, models.ErrCreatorIdIsNotSet)

		i.CreatorId = account.Id
		err = i.Create()
		So(err, ShouldBeNil)
		So(i.Id, ShouldNotEqual, 0)

	})

}

func TestChannelIntegrationGenerateToken(t *testing.T) {
	r := runner.New("test")
	if err := r.Init(); err != nil {
		t.Fatalf("couldnt start bongo %s", err)
	}
	defer r.Close()

	Convey("while generating a token", t, func() {
		Convey("it should be unique", func() {
			ci := NewChannelIntegration()
			token, err := ci.GenerateToken()
			So(err, ShouldBeNil)
			So(token, ShouldNotBeBlank)
			err = ci.ByToken(token)
			So(err, ShouldEqual, ErrChannelIntegrationNotFound)
		})
	})
}
