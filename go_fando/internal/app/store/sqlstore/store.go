package sqlstore

import (
	"database/sql"

	_ "github.com/lib/pq"

	"apiexample/internal/app/store"
)

type Store struct {
	db             *sql.DB
	userRepository *UserRepository
	operationRepo  *OperationRepository
	containerRepo  *ContainerRepository
	partnerRepo    *PartnerRepository
}

func NewStore(db *sql.DB) store.IStore {
	return &Store{
		db: db,
	}
}

// User
func (s *Store) User() store.IUserRepository {
	if s.userRepository == nil {
		s.userRepository = &UserRepository{
			store: s,
		}
	}

	return s.userRepository
}

func (s *Store) Operation() store.IOperationRepository {
	if s.operationRepo == nil {
		s.operationRepo = &OperationRepository{
			store: s,
		}
	}
	return s.operationRepo
}

func (s *Store) Container() store.IContainerRepository {
	if s.containerRepo == nil {
		s.containerRepo = &ContainerRepository{
			store: s,
		}
	}
	return s.containerRepo
}

func (s *Store) Partner() store.IPartnerRepository {
	if s.partnerRepo == nil {
		s.partnerRepo = &PartnerRepository{
			store: s,
		}
	}
	return s.partnerRepo
}

// в storage пишем все репозитории которые будем использовать
// один репозиторий - одна таблица
// в userRepository(и в других репозиториях) указываем параметр storage, чтобы все запросы шли через объект storage
// похоже это правильный стиль, но я не вижу ничего плохого писать всем репозиториям в параметр DB вместо storage
// и писать все запросы userReposirory.db.QueryRow по такому виду, а не userReposirory.storage.db.QueryRow
