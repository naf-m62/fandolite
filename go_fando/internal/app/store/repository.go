package store

import "apiexample/internal/app/model"

type IUserRepository interface {
	CreateUser(user *model.User) error
	Find(id int64) (*model.User, error)
	FindByEmail(s string) (*model.User, error)
	AddBall(userID int64) (err error)
}

type IOperationRepository interface {
	Create(operation *model.Operation) error
}

type IContainerRepository interface {
	GetAllowedBarcodes(containerID int64) ([]string, error)
}

type IPartnerRepository interface {
	GetPartnerList() ([]model.Partner, error)
}
