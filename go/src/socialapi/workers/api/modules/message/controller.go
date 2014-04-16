package message

import (
	"net/http"
	"net/url"
	"socialapi/models"
	"socialapi/workers/api/modules/helpers"

	"github.com/jinzhu/gorm"
)

func Create(u *url.URL, h http.Header, req *models.ChannelMessage) (int, http.Header, interface{}, error) {
	channelId, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	// override message type
	// all of the messages coming from client-side
	// should be marked as POST
	req.TypeConstant = models.ChannelMessage_TYPE_POST

	// set initial channel id
	req.InitialChannelId = channelId

	if err := req.Create(); err != nil {
		// todo this should be internal server error
		return helpers.NewBadRequestResponse(err)
	}

	cml := models.NewChannelMessageList()

	// override channel id
	cml.ChannelId = channelId
	cml.MessageId = req.Id
	if err := cml.Create(); err != nil {
		// todo this should be internal server error
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(req)
}

func Delete(u *url.URL, h http.Header, req *models.ChannelMessage) (int, http.Header, interface{}, error) {
	id, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	req.Id = id
	if err := req.Fetch(); err != nil {
		if err == gorm.RecordNotFound {
			return helpers.NewNotFoundResponse()
		}
		return helpers.NewBadRequestResponse(err)
	}

	//////////////// Delete All Related Data ///////////////////////
	// fetch message replies
	mr := models.NewMessageReply()
	mr.MessageId = id
	messageReplies, err := mr.List()
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	// delete message replies
	for _, messageReply := range messageReplies {
		// fetch interactions
		i := models.NewInteraction()
		i.MessageId = messageReply.Id
		interactions, err := i.FetchAll("like")
		if err != nil {
			return helpers.NewBadRequestResponse(err)
		}

		// delete interactions
		for _, interaction := range interactions {
			err := interaction.Delete()
			if err != nil {
				return helpers.NewBadRequestResponse(err)
			}
		}

		// delete messageReply itself
		err = messageReply.Delete()
		if err != nil {
			return helpers.NewBadRequestResponse(err)
		}
	}

	// now delete message itself
	if err := req.Delete(); err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	// yes it is deleted but not removed completely from our system
	return helpers.NewDeletedResponse()
}

func Update(u *url.URL, h http.Header, req *models.ChannelMessage) (int, http.Header, interface{}, error) {
	id, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}
	req.Id = id

	body := req.Body
	if err := req.Fetch(); err != nil {
		if err == gorm.RecordNotFound {
			return helpers.NewNotFoundResponse()
		}
		return helpers.NewBadRequestResponse(err)
	}

	if req.Id == 0 {
		return helpers.NewBadRequestResponse(err)
	}

	req.Body = body
	if err := req.Update(); err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(req)
}

func Get(u *url.URL, h http.Header, _ interface{}) (int, http.Header, interface{}, error) {
	id, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}
	cm := models.NewChannelMessage()
	cm.Id = id
	if err := cm.Fetch(); err != nil {
		if err == gorm.RecordNotFound {
			return helpers.NewNotFoundResponse()
		}
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(cm)
}

func GetWithRelated(u *url.URL, h http.Header, _ interface{}) (int, http.Header, interface{}, error) {
	id, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	cm := models.NewChannelMessage()
	cm.Id = id
	if err := cm.Fetch(); err != nil {
		if err == gorm.RecordNotFound {
			return helpers.NewNotFoundResponse()
		}
		return helpers.NewBadRequestResponse(err)
	}

	cmc, err := cm.BuildMessage(helpers.GetQuery(u))
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(cmc)
}
