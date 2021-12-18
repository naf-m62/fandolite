package model

import (
	"errors"
	"time"

	validation "github.com/go-ozzo/ozzo-validation/v3"
	"github.com/go-ozzo/ozzo-validation/v3/is"
	"golang.org/x/crypto/bcrypt"
)

type User struct {
	Id                int64     `json:"id"`
	Email             string    `json:"email"`
	Password          string    `json:"password,omitempty"`
	EncryptedPassword string    `json:"-"`
	Balls             int64     `json:"balls"`
	CreatedAt         time.Time `json:"createdAt"`
	UpdatedAt         time.Time `json:"updatedAt"`
}

func (u *User) ValidateUser() error {
	return validation.ValidateStruct(
		u,
		validation.Field(&u.Email, validation.Required, is.Email),
		validation.Field(&u.Password, validation.By(requiredIf(u.EncryptedPassword == "")), validation.Length(6, 50)),
	)
}

// BeforeCreate до создания пользователя
func (u *User) BeforeCreate() error {
	if len(u.Password) > 0 {
		enc, err := encryptString(u.Password)
		if err != nil {
			return err
		}
		u.EncryptedPassword = enc
		return nil
	}
	return errors.New("empty password")
}

//
func (u *User) ComparePassword(passwordFromRequest, hash string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(passwordFromRequest)) == nil
}

// Sanitize чтобы не передавать пароль во внешний мир
func (u *User) Sanitize() {
	u.Password = ""
}

// encryptString хеширует строку
func encryptString(p string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(p), bcrypt.MinCost)
	if err != nil {
		return "", err
	}
	return string(b), nil
}
