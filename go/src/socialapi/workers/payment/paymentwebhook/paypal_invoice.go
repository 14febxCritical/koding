package main

import (
	"socialapi/workers/payment/paymentemail"
	"socialapi/workers/payment/paymentwebhook/webhookmodels"
	"socialapi/workers/payment/paypal"
)

func paypalPaymentSucceeded(req *webhookmodels.PaypalGenericWebhook, c *Controller) error {
	err := paypal.UpdateCurrentPeriods(req.PayerId, req.PaymentDate.Time, req.NextPaymentDate.Time)
	if err != nil {
		return err
	}

	return paypalPaymentHelper(req, paymentemail.PaymentCreated, c)
}

func paypalPaymentFailed(req *webhookmodels.PaypalGenericWebhook, c *Controller) error {
	err := paypalExpireSubscription(req.PayerId, c.Kite)
	if err != nil {
		return err
	}

	return paypalPaymentHelper(req, paymentemail.PaymentFailed, c)
}

func paypalPaymentHelper(req *webhookmodels.PaypalGenericWebhook, action paymentemail.Action, c *Controller) error {
	opts := map[string]string{
		"planName": req.Plan,
		"price":    formatPaypalAmount(req.Currency, req.Amount),
	}

	emailAddress, err := getEmailForCustomer(req.PayerId)
	if err != nil {
		return err
	}

	Log.Info("Paypal: Sent paypal email to: %s with plan: %s", emailAddress, req.Plan)

	return paymentemail.Send(c.Email, action, emailAddress, opts)
}
