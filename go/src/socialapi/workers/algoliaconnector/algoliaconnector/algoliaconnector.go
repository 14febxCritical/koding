package algoliaconnector

import (
	"encoding/json"
	"errors"
	"fmt"
	"socialapi/models"
	"strconv"

	"github.com/algolia/algoliasearch-client-go/algoliasearch"
	"github.com/koding/logging"
	"github.com/streadway/amqp"
)

var (
	ErrAlgoliaObjectIdNotFoundMsg = "ObjectID does not exist"
	ErrAlgoliaIndexNotExistMsg    = "Index messages.test does not exist"
)

type IndexSet map[string]*algoliasearch.Index

type Controller struct {
	log     logging.Logger
	client  *algoliasearch.Client
	indexes *IndexSet
}

// IsAlgoliaError checks if the given algolia error string and given messages
// are same according their data structure
func IsAlgoliaError(err error, message string) bool {
	if err == nil {
		return false
	}

	v := &algoliaErrorRes{}

	if err := json.Unmarshal([]byte(err.Error()), v); err != nil {
		return false
	}

	if v.Message == message {
		return true
	}

	return false
}

type algoliaErrorRes struct {
	Message string `json:"message"`
	Status  int    `json:"status"`
}

func (i *IndexSet) Get(name string) (*algoliasearch.Index, error) {
	index, ok := (*i)[name]
	if !ok {
		return nil, fmt.Errorf("Unknown index: '%s'", name)
	}
	return index, nil
}

func (c *Controller) DefaultErrHandler(delivery amqp.Delivery, err error) bool {
	c.log.Error(err.Error())
	return false
}

func New(log logging.Logger, client *algoliasearch.Client, indexSuffix string) *Controller {
	return &Controller{
		log:    log,
		client: client,
		indexes: &IndexSet{
			"topics":   client.InitIndex("topics" + indexSuffix),
			"accounts": client.InitIndex("accounts" + indexSuffix),
			"messages": client.InitIndex("messages" + indexSuffix),
		},
	}
}

func (f *Controller) TopicSaved(data *models.Channel) error {
	if data.TypeConstant != models.Channel_TYPE_TOPIC {
		return nil
	}
	return f.insert("topics", map[string]interface{}{
		"objectID": strconv.FormatInt(data.Id, 10),
		"name":     data.Name,
		"purpose":  data.Purpose,
	})
}

// TopicUpdated handles the channel update events, for now only handles the
// channels that are topic channels, we can link channels together in any point
// of time, after linking, leaf channel should be removed from search engine
func (f *Controller) TopicUpdated(data *models.Channel) error {
	if data.TypeConstant != models.Channel_TYPE_LINKED_TOPIC {
		f.log.Debug("unsuported channel for topic update type: %s id: %d", data.TypeConstant, data.Id)
		return nil
	}

	return f.delete("topics", strconv.FormatInt(data.Id, 10))
}

func (f *Controller) AccountSaved(data *models.Account) error {
	return f.insert("accounts", map[string]interface{}{
		"objectID": data.OldId,
		"nick":     data.Nick,
	})
}

func (f *Controller) MessageListSaved(listing *models.ChannelMessageList) error {
	message := models.NewChannelMessage()

	if err := message.ById(listing.MessageId); err != nil {
		return err
	}

	objectId := strconv.FormatInt(message.Id, 10)
	channelId := strconv.FormatInt(listing.ChannelId, 10)

	record, err := f.get("messages", objectId)
	if err != nil &&
		!IsAlgoliaError(err, ErrAlgoliaObjectIdNotFoundMsg) &&
		!IsAlgoliaError(err, ErrAlgoliaIndexNotExistMsg) {
		return err
	}

	if record == nil {
		return f.insert("messages", map[string]interface{}{
			"objectID": objectId,
			"body":     message.Body,
			"_tags":    []string{channelId},
		})
	}

	return f.partialUpdate("messages", map[string]interface{}{
		"objectID": objectId,
		"_tags":    appendMessageTag(record, channelId),
	})
}

func (f *Controller) MessageListDeleted(listing *models.ChannelMessageList) error {
	index, err := f.indexes.Get("messages")
	if err != nil {
		return err
	}

	objectId := strconv.FormatInt(listing.MessageId, 10)

	record, err := f.get("messages", objectId)
	if err != nil &&
		!IsAlgoliaError(err, ErrAlgoliaObjectIdNotFoundMsg) &&
		!IsAlgoliaError(err, ErrAlgoliaIndexNotExistMsg) {
		return err
	}

	if tags, ok := record["_tags"]; ok {
		if t, ok := tags.([]interface{}); ok && len(t) == 1 {
			if _, err = index.DeleteObject(objectId); err != nil {
				return err
			}
			return nil
		}
	}

	return f.partialUpdate("messages", map[string]interface{}{
		"objectID": objectId,
		"_tags":    removeMessageTag(record, strconv.FormatInt(listing.ChannelId, 10)),
	})
}

func (f *Controller) MessageUpdated(message *models.ChannelMessage) error {
	return f.partialUpdate("messages", map[string]interface{}{
		"objectID": strconv.FormatInt(message.Id, 10),
		"body":     message.Body,
	})
}

func (f *Controller) CreateSynonym(cl *models.ChannelLink) error {
	if err := f.validateSynonymRequest(cl); err != nil {
		f.log.Error("CreateSynonym validateSynonymRequest err:", err.Error())
		return nil
	}

	return nil
}

func (f *Controller) DeleteSynonym(cl *models.ChannelLink) error {
	if err := f.validateSynonymRequest(cl); err != nil {
		f.log.Error("DeleteSynonym validateSynonymRequest err:", err.Error())
		return nil
	}

	return nil
}

func (f *Controller) validateSynonymRequest(cl *models.ChannelLink) error {
	// check required variables
	if cl == nil {
		return errors.New("channel link is not set (nil)")
	}

	if cl.Id == 0 {
		return errors.New("id is not set")
	}

	if cl.RootId == 0 {
		return errors.New("root id is not set")
	}

	if cl.LeafId == 0 {
		return errors.New("leaf id is not set")
	}

	// check channel types
	rootChannel, err := models.ChannelById(cl.RootId)
	if err != nil {
		return err
	}

	if !isValidChannelType(rootChannel) {
		return errors.New("root is not valid type for synonym")
	}

	leafChannel, err := models.ChannelById(cl.LeafId)
	if err != nil {
		return err
	}

	if !isValidChannelType(leafChannel) {
		return errors.New("leaf is not valid type for synonym")
	}

	return nil
}

func isValidChannelType(c *models.Channel) bool {
	return models.IsIn(
		c.TypeConstant,
		models.Channel_TYPE_TOPIC,
		models.Channel_TYPE_LINKED_TOPIC,
	)
}
