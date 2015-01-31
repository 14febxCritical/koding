package main

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	. "github.com/smartystreets/goconvey/convey"
)

var controller *Controller

func init() {
	r := initializeRunner()
	conf := r.Conf

	// initialize client to talk to kloud
	kiteClient := initializeKiteClient(r.Kite, conf.Kloud.SecretKey, conf.Kloud.Address)

	// initialize client to send email
	email := initializeEmail(conf.Email)

	// initialize controller to inject dependencies
	cont := &Controller{Kite: kiteClient, Email: email}

	controller = cont
}

func TestMux(t *testing.T) {
	Convey("Given mux", t, func() {
		st := &stripeMux{Controller: controller}
		pp := &paypalMux{Controller: controller}

		mux := initializeMux(st, pp)

		Convey("It should redirect stripe properly", func() {
			r, err := http.NewRequest("POST", "/-/payments/stripe/webhook", bytes.NewBuffer([]byte{}))
			So(err, ShouldBeNil)

			recorder := httptest.NewRecorder()

			mux.ServeHTTP(recorder, r)
			So(recorder.Code, ShouldNotEqual, 404)
		})

		Convey("It should redirect paypal properly", func() {
			r, err := http.NewRequest("POST", "/-/payments/paypal/webhook", bytes.NewBuffer([]byte{}))
			So(err, ShouldBeNil)

			recorder := httptest.NewRecorder()

			mux.ServeHTTP(recorder, r)
			So(recorder.Code, ShouldNotEqual, 404)
		})
	})
}
