package account

import (
	"net/http"
	"net/url"
	"socialapi/models"
	"socialapi/workers/api/modules/helpers"
)

func ListChannels(u *url.URL, h http.Header, _ interface{}) (int, http.Header, interface{}, error) {
	query := helpers.GetQuery(u)

	accountId, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	if query.Type == "" {
		query.Type = models.Channel_TYPE_TOPIC
	}

	a := &models.Account{Id: accountId}
	channels, err := a.FetchChannels(query)
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(models.PopulateChannelContainers(channels, accountId))
}
}

func Follow(u *url.URL, h http.Header, req *models.Account) (int, http.Header, interface{}, error) {
	targetId, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	cp, err := req.Follow(targetId)
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(cp)
}

func Register(u *url.URL, h http.Header, req *models.Account) (int, http.Header, interface{}, error) {

	if err := req.FetchOrCreate(); err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	return helpers.NewOKResponse(req)
}

func Unfollow(u *url.URL, h http.Header, req *models.Account) (int, http.Header, interface{}, error) {
	targetId, err := helpers.GetURIInt64(u, "id")
	if err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	if err := req.Unfollow(targetId); err != nil {
		return helpers.NewBadRequestResponse(err)
	}

	// req shouldnt be returned?
	return helpers.NewOKResponse(req)
}
