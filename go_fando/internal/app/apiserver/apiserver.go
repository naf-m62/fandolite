package apiserver

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/sessions"

	"apiexample/internal/app/store/sqlstore"
)

func Start(config *Config) error {
	db, err := newDB(config.Store)
	if err != nil {
		return err
	}

	defer db.Close()

	store := sqlstore.NewStore(db)
	sessionsStore := sessions.NewCookieStore([]byte(config.SessionsKey))
	srv := newServer(store, sessionsStore)

	srv.logger.Info("api server start on:", config.BindAddr)

	return http.ListenAndServe(config.BindAddr, srv)
}

func newDB(config sqlstore.Config) (*sql.DB, error) {
	dsn := fmt.Sprintf("user=%s password=%s dbname=%s sslmode=disable", config.Username, config.Password, config.DBName)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		log.Println(err)
		return nil, err
	}

	return db, nil
}
