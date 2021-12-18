package sqlstore

import "apiexample/internal/app/model"

type OperationRepository struct {
	store *Store
}

func (o *OperationRepository) Create(operation *model.Operation) (err error) {
	_, err = o.store.db.Exec(
		`INSERT INTO operations(user_id, barcode, container_id) VALUES ($1, $2, $3)`,
		operation.UserID,
		operation.Barcode,
		operation.ContainerID,
	)
	return err
}
