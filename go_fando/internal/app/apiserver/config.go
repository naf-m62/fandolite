package apiserver

import "apiexample/internal/app/store/sqlstore"

type Config struct {
	BindAddr    string          `yaml:"bind_addr"`
	LogLevel    string          `yaml:"log_level"`
	SessionsKey string          `yaml:"sessions_key"`
	Store       sqlstore.Config `yaml:"store"`
}
