package api

import (
	"socialapi/models"
	"socialapi/workers/common/handler"
	"socialapi/workers/common/mux"
)

func AddHandlers(m *mux.Mux) {
	m.AddHandler(
		handler.Request{
			Handler:  CreateLink,
			Name:     models.ModerationChannelCreateLink,
			Type:     handler.PostRequest,
			Endpoint: "/moderation/channel/{rootId}/link",
		},
	)

	m.AddHandler(
		handler.Request{
			Handler:  GetLinks,
			Name:     models.ModerationChannelGetLink,
			Type:     handler.GetRequest,
			Endpoint: "/moderation/channel/{rootId}/link",
		},
	)

	m.AddHandler(
		handler.Request{
			Handler:  DeleteLink,
			Name:     models.ModerationChannelDeleteLink,
			Type:     handler.DeleteRequest,
			Endpoint: "/moderation/channel/{rootId}/link/{leafId}",
		},
	)

	m.AddHandler(
		handler.Request{
			Handler:  Blacklist,
			Name:     models.ModerationChannelBlacklist,
			Type:     handler.DeleteRequest,
			Endpoint: "/moderation/channel/{leafId}",
		},
	)
}
