package model

import "time"

type Container struct {
	ID              int64
	Type            string
	AllowedBarcodes []string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}
