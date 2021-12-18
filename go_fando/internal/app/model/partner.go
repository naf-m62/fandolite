package model

import "time"

type Partner struct {
	ID          int64     `json:"id"`
	PartnerName string    `json:"partnerName"`
	Description string    `json:"description"`
	Condition   int64     `json:"condition"`
	ImageUrl    string    `json:"imageUrl"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}
