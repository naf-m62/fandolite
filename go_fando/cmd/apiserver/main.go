package main

import (
	"apiexample/internal/app/apiserver"
	"flag"
	"io/ioutil"
	"log"

	"gopkg.in/yaml.v2"
)

func main() {
	var configPath string
	flag.StringVar(&configPath, "c", "configs/apiserver.yml", "path to config file")
	flag.Parse()

	config := new(apiserver.Config)
	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		log.Fatal("error reading config file: ", err)
	}

	if err := yaml.Unmarshal(configData, config); err != nil {
		log.Fatal("Unmarshal error:", err)
	}

	if err := apiserver.Start(config); err != nil {
		log.Println("start api server error", err)
		return
	}
	return
}
