package store

type IStore interface {
	User() IUserRepository
	Operation() IOperationRepository
	Container() IContainerRepository
	Partner() IPartnerRepository
}
