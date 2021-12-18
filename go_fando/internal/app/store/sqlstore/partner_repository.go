package sqlstore

import (
	"database/sql"

	"apiexample/internal/app/model"
)

type PartnerRepository struct {
	store *Store
}

func (p *PartnerRepository) GetPartnerList() (partnerList []model.Partner, err error) {
	var rows *sql.Rows
	if rows, err = p.store.db.Query(
		"SELECT id, partner_name, description, condition, image_url, created_at, updated_at FROM partners order by id desc",
	); err != nil {
		return nil, err
	}

	defer func() { _ = rows.Close() }()

	for rows.Next() {
		p := model.Partner{}
		if err = rows.Scan(
			&p.ID,
			&p.PartnerName,
			&p.Description,
			&p.Condition,
			&p.ImageUrl,
			&p.CreatedAt,
			&p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		partnerList = append(partnerList, p)
	}
	return partnerList, nil
}
