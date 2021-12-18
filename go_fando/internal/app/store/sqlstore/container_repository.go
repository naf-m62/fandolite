package sqlstore

import "github.com/lib/pq"

type ContainerRepository struct {
	store *Store
}

func (c *ContainerRepository) GetAllowedBarcodes(containerID int64) (allowedList []string, err error) {
	err = c.store.db.QueryRow(`SELECT allowed_barcodes FROM containers WHERE id = $1`, containerID).
		Scan(pq.Array(&allowedList))
	return allowedList, err
}
