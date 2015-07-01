package main

import (
	"fmt"
	"koding/kites/kloud/pkg/dnsclient"

	"github.com/mitchellh/goamz/route53"
)

type TestDomains struct {
	DNS     *dnsclient.Route53
	records []*dnsclient.Record
	err     error
}

func (t *TestDomains) Process() {
	fmt.Println("Processing TestDomains")

	prevRecord := ""
	lastRecord := ""
	t.records = make([]*dnsclient.Record, 0)

	for {
		records, err := t.DNS.GetAll(lastRecord)
		if err != nil {
			t.err = err
			return
		}

		lastRecord = records[len(records)-1].Name
		if lastRecord == prevRecord {
			break
		}

		prevRecord = lastRecord

		// do not include the first record, because it's alread included in the
		// previous round
		for _, record := range records[1:] {
			// do not add NS records
			if record.Name != "dev.koding.io." {
				t.records = append(t.records, record)
			}
		}

	}

	fmt.Printf("Fetched '%d' domains\n", len(t.records))
}

func (t *TestDomains) Run() {
	if len(t.records) == 0 {
		return
	}

	fmt.Printf("Removing '%d' test domains\n", len(t.records))

	for _, records := range splittedRecords(t.records, 100) {
		changes := make([]route53.Change, len(records))
		for i, r := range records {
			changes[i] = route53.Change{
				Action: "DELETE",
				Record: route53.ResourceRecordSet{
					Type:    "A",
					Name:    r.Name,
					TTL:     r.TTL,
					Records: []string{r.IP},
				},
			}

		}

		changeResourceSet := &route53.ChangeResourceRecordSetsRequest{
			Comment: "Deleting domain",
			Changes: changes,
		}

		_, err := t.DNS.ChangeResourceRecordSets(t.DNS.ZoneId, changeResourceSet)
		if err != nil {
			t.err = err
			return
		}
	}
}

func (t *TestDomains) Result() string {
	if t.err != nil {
		return fmt.Sprintf("testDomains: error '%s'", t.err.Error())
	}

	return fmt.Sprintf("removed '%d' development domains from dev.koding.io hosted zone",
		len(t.records))
}

func (t *TestDomains) Info() *taskInfo {
	return &taskInfo{
		Title: "TestDomains",
		Desc:  "Delete domains belonging to development and sandbox environment.",
	}
}

func splittedRecords(records []*dnsclient.Record, split int) [][]*dnsclient.Record {
	if split == 0 {
		panic("split number must be greater than 0")
	}

	// we split the records because AWS doesn't allow us to remove more than 100
	// records, so for example if we have 350 records, we'll going to make four
	// API calls with records of 100, 100, 100 and 50
	var splitted [][]*dnsclient.Record
	for len(records) >= split {
		splitted = append(splitted, records[:split])
		records = records[split:]
	}
	splitted = append(splitted, records) // remaining
	return splitted
}
