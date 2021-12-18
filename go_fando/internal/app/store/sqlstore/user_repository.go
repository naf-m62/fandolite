package sqlstore

import "apiexample/internal/app/model"

type UserRepository struct {
	store *Store
}

// CreateUser создать пользователя
func (ur *UserRepository) CreateUser(user *model.User) error {
	if err := user.ValidateUser(); err != nil {
		return err
	}

	if err := user.BeforeCreate(); err != nil {
		return err
	}

	if err := ur.store.db.QueryRow(
		"INSERT INTO users (email, encrypted_password) VALUES ($1, $2) RETURNING id",
		user.Email,
		user.EncryptedPassword,
	).Scan(&user.Id); err != nil {
		return err
	}

	return nil
}

// FindByEmail найти по email
func (ur *UserRepository) FindByEmail(email string) (*model.User, error) {
	user := &model.User{}
	if err := ur.store.db.QueryRow(
		"SELECT id, balls, email, encrypted_password FROM users WHERE email = $1",
		email,
	).Scan(
		&user.Id,
		&user.Balls,
		&user.Email,
		&user.EncryptedPassword,
	); err != nil {
		return nil, err
	}
	return user, nil
}

// Find
func (ur *UserRepository) Find(id int64) (*model.User, error) {
	user := &model.User{}
	if err := ur.store.db.QueryRow(
		"SELECT id, email, encrypted_password, balls, created_at, updated_at FROM users WHERE id = $1",
		id,
	).Scan(
		&user.Id,
		&user.Email,
		&user.EncryptedPassword,
		&user.Balls,
		&user.CreatedAt,
		&user.UpdatedAt,
	); err != nil {
		return nil, err
	}
	return user, nil
}

// AddBall добавить баллы
func (ur *UserRepository) AddBall(userID int64) (err error) {
	_, err = ur.store.db.Exec(
		"UPDATE users SET balls = coalesce(balls,0) + 1, updated_at = now() WHERE id = $1",
		&userID,
	)
	return err
}
