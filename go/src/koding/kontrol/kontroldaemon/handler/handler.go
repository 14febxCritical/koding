package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/streadway/amqp"
	"koding/db/models"
	"koding/db/mongodb"
	"koding/db/mongodb/modelhelper"
	"koding/kontrol/kontroldaemon/workerconfig"
	"koding/kontrol/kontrolhelper"
	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

type IncomingMessage struct {
	Worker  *models.Worker
	Monitor *models.Monitor
}

var producer *kontrolhelper.Producer

func init() {
	log.SetPrefix(fmt.Sprintf("kontrold [%5d] ", os.Getpid()))
}

func Startup() {
	var err error
	producer, err = kontrolhelper.CreateProducer("worker")
	if err != nil {
		log.Println(err)
	}

	err = producer.Channel.ExchangeDeclare("clientExchange", "fanout", true, false, false, false, nil)
	if err != nil {
		log.Printf("clientExchange exchange.declare: %s", err)
	}

	runHelperFunctions()

	log.Println("kontrold handler is initialized")
}

// runHelperFunctions contains several indepenendent helper functions that do
// certain tasks.
func runHelperFunctions() {
	// HeartBeat checker for workers
	tickerWorker := time.NewTicker(workerconfig.HEARTBEAT_INTERVAL)
	go func() {
		queryFunc := func(c *mgo.Collection) error {
			worker := models.Worker{}
			iter := c.Find(nil).Iter()
			for iter.Next(&worker) {
				if worker.Status == models.Dead {
					continue // already dead, nothing to do
				}

				if time.Now().Before(worker.Timestamp.Add(workerconfig.HEARTBEAT_DELAY)) {
					continue // still alive, pick up the next one
				}

				log.Printf("[%s (%d)] no activity at '%s' - '%s' (pid: %d). marking them as dead\n",
					worker.Name,
					worker.Version,
					worker.Hostname,
					worker.Uuid,
					worker.Pid,
				)

				worker.Status = models.Dead
				worker.Monitor.Mem = models.MemData{}
				worker.Monitor.Uptime = 0
				modelhelper.UpdateIDWorker(worker)
			}

			if err := iter.Close(); err != nil {
				return err
			}

			return nil
		}

		for _ = range tickerWorker.C {
			mongodb.Run("jKontrolWorkers", queryFunc)
		}
	}()

	// Cleanup dead deployments at intervals. This goroutine will lookup at
	// each information if a deployment has running workers. If workers for a
	// certain deployment is not running anymore, then it will remove the
	// deployment information and all workers associated with that deployment
	// build.
	tickerDeployment := time.NewTicker(time.Hour * 1)
	go func() {
		for _ = range tickerDeployment.C {
			log.Println("cleaner started to remove unused deployments and dead workers")
			infos := modelhelper.GetClients()
			for _, info := range infos {
				version, _ := strconv.Atoi(info.BuildNumber)

				// look if any workers are running for a certain version
				foundWorker := false
				query := func(c *mgo.Collection) error {
					iter := c.Find(bson.M{"version": version, "status": int(models.Started)}).Iter()
					worker := models.Worker{}
					for iter.Next(&worker) {
						foundWorker = true
					}

					if err := iter.Close(); err != nil {
						return err
					}

					return nil
				}

				mongodb.Run("jKontrolWorkers", query)

				// ... if not remove deployment information and dead workers of that version
				if !foundWorker {
					log.Printf("removing deployment info for build number %s\n", info.BuildNumber)
					err := modelhelper.DeleteClient(info.BuildNumber)
					if err != nil {
						log.Println(err)
					}

					log.Printf("removing dead workers for build number %s\n", info.BuildNumber)
					query := func(c *mgo.Collection) error {
						_, err := c.RemoveAll(bson.M{"version": version, "status": int(models.Dead)})
						return err
					}

					err = mongodb.Run("jKontrolWorkers", query)
					if err != nil {
						log.Println(err)
					}
				}
			}
		}
	}()
}

func ClientMessage(data amqp.Delivery) {
	if data.RoutingKey == "kontrol-client" {
		var info models.ServerInfo
		err := json.Unmarshal(data.Body, &info)
		if err != nil {
			log.Print("bad json client msg: ", err)
		}

		modelhelper.AddClient(info)
	}
}

func WorkerMessage(data []byte) {
	var msg IncomingMessage
	err := json.Unmarshal(data, &msg)
	if err != nil {
		log.Print("bad json incoming msg: ", err)
	}

	if msg.Monitor != nil {
		err := SaveMonitorData(msg.Monitor)
		if err != nil {
			log.Println(err)
		}
	} else if msg.Worker != nil {
		err = DoWorkerCommand(msg.Worker.Message.Command, *msg.Worker)
		if err != nil {
			log.Println(err)
		}
	} else {
		log.Println("incoming message is in wrong format")
	}
}

func ApiMessage(data []byte) {
	var req workerconfig.ApiRequest
	err := json.Unmarshal(data, &req)
	if err != nil {
		log.Print("bad json incoming msg: ", err)
	}

	err = DoApiRequest(req.Command, req.Uuid)
	if err != nil {
		log.Println(err)
	}
}

// DoWorkerCommand is used to handle messages coming from workers.
func DoWorkerCommand(command string, worker models.Worker) error {
	if worker.Uuid == "" {
		fmt.Errorf("worker %s does have an empty uuid", worker.Name)
	}

	switch command {
	case "add", "addWithProxy":
		// This is a large and complex process, handle it seperately.
		// "res" will be send to the worker, it contains the permission result
		res, err := handleAdd(worker)
		if err != nil {
			return err
		}
		go deliver(res)

		// rest is proxy related
		if command != "addWithProxy" {
			return nil
		}

		if worker.Port == 0 { // zero port is useless for proxy
			return fmt.Errorf("register to kontrol proxy not possible. port number is '0' for %s", worker.Name)
		}

		mode := "roundrobin"
		if worker.Name == "broker" {
			mode = "sticky"
		}

		port := strconv.Itoa(worker.Port)
		key := strconv.Itoa(worker.Version)
		err = modelhelper.UpsertKey(
			"koding",    // username
			"",          // persistence, empty means disabled
			mode,        // loadbalancing mode
			worker.Name, // servicename
			key,         // version
			worker.Hostname+":"+port, // host
			"FromKontrolDaemon",      // hostdata
			"",                       // rabbitkey, not used
		)
		if err != nil {
			return fmt.Errorf("register to kontrol proxy not possible: %s", err.Error())
		}
	case "ack":
		err := workerconfig.Ack(worker)
		if err != nil {
			return err
		}
	case "update":
		log.Printf("[%s (%d)] update request from: '%s' - '%s'",
			worker.Name,
			worker.Version,
			worker.Hostname,
			worker.Uuid,
		)
		err := workerconfig.Update(worker)
		if err != nil {
			return err
		}
	default:
		return fmt.Errorf(" command not recognized: %s", command)
	}

	return nil
}

// DoApiRequest is used to make actions on workers. You can kill, delete or
// start any worker with this api.
func DoApiRequest(command, uuid string) error {
	if uuid == "" {
		errors.New("empty uuid is not allowed.")
	}

	log.Printf("[%s] received: %s", uuid, command)
	switch command {
	case "delete":
		err := workerconfig.Delete(uuid)
		if err != nil {
			return err
		}
	case "kill":
		res, err := workerconfig.Kill(uuid, "normal")
		if err != nil {
			log.Println(err)
		}
		go deliver(res)
	case "start":
		res, err := workerconfig.Start(uuid)
		if err != nil {
			log.Println(err)
		}
		go deliver(res)
	default:
		return fmt.Errorf(" command not recognized: %s", command)
	}
	return nil
}

func SaveMonitorData(data *models.Monitor) error {
	worker, err := modelhelper.GetWorker(data.Uuid)
	if err != nil {
		return fmt.Errorf("monitor data error '%s'", err)
	}

	worker.Monitor.Mem = *data.Mem
	worker.Monitor.Uptime = data.Uptime
	modelhelper.UpdateWorker(worker)
	return nil
}

func handleAdd(worker models.Worker) (workerconfig.WorkerResponse, error) {
	option := worker.Message.Option

	switch option {
	case "force":
		// force mode immediately run the worker, however before it will run,
		// it tries to find all workers with the same name(foo and foo-1 counts
		// as the same) on other host's. Basically 'force' mode makes the
		// worker exclusive on all machines and no other worker with the same
		// name can run anymore.
		log.Printf("[%s (%d)] killing all other workers except hostname '%s'\n",
			worker.Name, worker.Version, worker.Hostname)

		result := models.Worker{}
		query := func(c *mgo.Collection) error {
			iter := c.Find(bson.M{
				"name": bson.RegEx{Pattern: "^" + normalizeName(worker.Name),
					Options: "i"},
				"hostname": bson.M{"$ne": worker.Hostname},
			}).Iter()
			for iter.Next(&result) {
				res, err := workerconfig.Kill(result.Uuid, "force")
				if err != nil {
					log.Println(err)
				}
				go deliver(res)

				err = workerconfig.Delete(result.Uuid)
				if err != nil {
					log.Println(err)
				}
			}

			return nil

		}

		mongodb.Run("jKontrolWorkers", query)

		startLog := fmt.Sprintf("[%s (%d) - (%s)] starting at '%s' - '%s'",
			worker.Name,
			worker.Version,
			option,
			worker.Hostname,
			worker.Uuid,
		)
		log.Println(startLog)

		worker.Status = models.Started
		worker.ObjectId = bson.NewObjectId()
		modelhelper.UpsertWorker(worker)

		response := *workerconfig.NewWorkerResponse(
			worker.Name,
			worker.Uuid,
			"start",
			startLog,
		)
		return response, nil
	case "one", "version":
		query := bson.M{}
		reason := ""

		// one means that only one single instance of the worker can work. For
		// example if we start an emailWorker with the mode "one", another
		// emailWorker don't get the permission to run.
		if option == "one" {
			query = bson.M{
				"name":   worker.Name,
				"status": bson.M{"$in": []int{int(models.Started), int(models.Waiting)}},
			}

			reason = "workers with same names: "
		}

		// version is like one, but it's allow only workers of the same name
		// and version. For example if an authWorker of version 13 starts with
		// the mode "version", than only authWorkers of version 13 can start,
		// any other authworker different than 13 (say, 10, 14, ...) don't get
		// the permission to run.
		if option == "version" {
			query = bson.M{
				"name": bson.RegEx{Pattern: "^" + normalizeName(worker.Name),
					Options: "i"},
				"version": bson.M{"$ne": worker.Version},
				"status":  bson.M{"$in": []int{int(models.Started), int(models.Waiting)}},
			}

			reason = "workers with different versions: "
		}

		worker.ObjectId = bson.NewObjectId()
		worker.Status = models.Started

		// If the query above for 'one' and 'version' doesn't match anything,
		// then add our new worker. Apply() is atomic and uses findAndModify.
		// Adding it causes no err, therefore the worker get 'start' message.
		// However if the query matches, then the 'upsert' will fail (means
		// that there is some workers that are running).
		change := mgo.Change{
			Update: worker,
			Upsert: true,
		}

		result := models.Worker{}
		err := mongodb.Run("jKontrolWorkers", func(c *mgo.Collection) error {
			_, err := c.Find(query).Apply(change, &result)
			return err
		})

		if err == nil {
			startLog := fmt.Sprintf("[%s (%d) - (%s)] starting at '%s' - '%s'", worker.Name, worker.Version, option, worker.Hostname, worker.Uuid)
			log.Println(startLog)
			response := *workerconfig.NewWorkerResponse(worker.Name, worker.Uuid, "start", startLog)
			return response, nil
		}

		reason = reason + fmt.Sprintf("\n version: %d (pid: %d) at %s", result.Version, result.Pid, result.Hostname)
		denyLog := fmt.Sprintf("[%s (%d)] denied at '%s'. reason: %s", worker.Name, worker.Version, worker.Hostname, reason)
		response := *workerconfig.NewWorkerResponse(worker.Name, worker.Uuid, "noPermission", denyLog)
		return response, nil // contains start or noPermission

	case "many":
		// many just starts the worker. That means a worker can be started as
		// many times as we wished with this option.
		startLog := fmt.Sprintf("[%s (%d) - (%s)] starting at '%s' - '%s'",
			worker.Name,
			worker.Version,
			option,
			worker.Hostname,
			worker.Uuid,
		)
		log.Println(startLog)

		worker.ObjectId = bson.NewObjectId()
		worker.Status = models.Started
		worker.Timestamp = time.Now().Add(workerconfig.HEARTBEAT_INTERVAL)
		modelhelper.UpsertWorker(worker)

		response := *workerconfig.NewWorkerResponse(
			worker.Name,
			worker.Uuid,
			"start",
			startLog,
		)
		return response, nil //
	default:
		return workerconfig.WorkerResponse{},
			errors.New("no option specified for add action. aborting add handler...")
	}

	return workerconfig.WorkerResponse{}, errors.New("couldn't add any worker")

}

func deliver(res workerconfig.WorkerResponse) {
	data, err := json.Marshal(res)
	if err != nil {
		log.Printf("could not marshall worker: %s", err)
	}

	msg := amqp.Publishing{
		Headers:         amqp.Table{},
		ContentType:     "text/plain",
		ContentEncoding: "",
		Body:            data,
		DeliveryMode:    1, // 1=non-persistent, 2=persistent
		Priority:        0, // 0-9
	}

	if res.Uuid == "" {
		log.Printf("can't send to worker. appId is missing")
	}
	workerOut := "output.worker." + res.Uuid
	err = producer.Channel.Publish("workerExchange", workerOut, false, false, msg)
	if err != nil {
		log.Printf("error while publishing message: %s", err)
	}
	// log.Println("SENDING WORKER data ", string(data))
}

// convert foo-1, foo-*, etc to foo
func normalizeName(name string) string {
	if counts := strings.Count(name, "-"); counts > 0 {
		return strings.Split(name, "-")[0]
	}
	return name
}
