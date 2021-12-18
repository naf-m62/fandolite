package model

import (
	"time"

	validation "github.com/go-ozzo/ozzo-validation/v3"
)

type Operation struct {
	ID          int64
	UserID      int64
	Barcode     string
	ContainerID int64
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Validate
func (o *Operation) Validate() error {
	return validation.ValidateStruct(
		o,
		validation.Field(&o.UserID, validation.Required, validation.Min(1)),
		validation.Field(&o.Barcode, validation.Required, validation.Min(1)),
		validation.Field(&o.ContainerID, validation.Required, validation.Min(1)),
	)
}
