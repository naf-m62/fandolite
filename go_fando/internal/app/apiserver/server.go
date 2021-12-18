package apiserver

import (
	"apiexample/internal/app/store"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/gorilla/sessions"
	"github.com/sirupsen/logrus"

	"apiexample/internal/app/helpers"
	"apiexample/internal/app/model"
)

const (
	sessionsName        = "authorization"
	ctxKeyUser   ctxKey = iota
	ctxKeyRequestId
)

type ctxKey int8

type server struct {
	logger        *logrus.Logger
	router        *mux.Router
	store         store.IStore
	sessionsStore *sessions.CookieStore
}

func newServer(store store.IStore, sessionsStore *sessions.CookieStore) *server {
	s := &server{
		logger:        logrus.New(),
		router:        mux.NewRouter(),
		store:         store,
		sessionsStore: sessionsStore,
	}

	s.configureRouter()

	return s
}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.router.ServeHTTP(w, r)
}

// configureRouter настройка роутера
func (s *server) configureRouter() {
	s.router.Use(s.SetRequestId)
	s.router.Use(s.logRequest)
	s.router.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		s.respond(w, http.StatusOK, "PONG")
	}).Methods("GET")
	s.router.HandleFunc("/users", s.handleUserCreate()).Methods("POST")
	s.router.HandleFunc("/sessions", s.handleSessionCreate()).Methods("POST")
	s.router.HandleFunc("/operation", s.handleOperationCreate()).Methods("POST")
	s.router.HandleFunc("/ball", s.handleAddBall()).Methods("PUT")
	s.router.HandleFunc("/info", s.handleGetUserInfo()).Methods("GET")
	s.router.HandleFunc("/partners", s.handleGetPartnerList()).Methods("GET")

	private := s.router.PathPrefix("/private").Subrouter()
	private.Use(s.authenticateUser)
	private.HandleFunc("/whoami", s.HandleWhoami()).Methods("GET")
}

// handleUserCreate обработчик роута /users
func (s *server) handleUserCreate() http.HandlerFunc {
	type request struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	return func(w http.ResponseWriter, r *http.Request) {
		req := request{}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			s.error(w, http.StatusBadRequest, err)
			return
		}

		u := &model.User{
			Email:    req.Email,
			Password: req.Password,
		}

		if err := s.store.User().CreateUser(u); err != nil {
			s.error(w, http.StatusUnprocessableEntity, err)
			return
		}

		u.Sanitize()
		s.respond(w, http.StatusCreated, u)
	}
}

// handleSessionCreate обработчик роута sessions
func (s *server) handleSessionCreate() http.HandlerFunc {
	type request struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	return func(w http.ResponseWriter, r *http.Request) {
		req := request{}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			s.error(w, http.StatusBadRequest, err)
			return
		}

		u, err := s.store.User().FindByEmail(req.Email)
		if err != nil || !u.ComparePassword(req.Password, u.EncryptedPassword) {
			s.error(w, http.StatusNotAcceptable, errors.New("incorrect email or password"))
		}

		session, err := s.sessionsStore.Get(r, sessionsName)
		if err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}

		session.Values["userId"] = u.Id
		if err := s.sessionsStore.Save(r, w, session); err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}
		s.respond(w, http.StatusOK, u)
	}
}

// handleOperationCreate создает операцию
func (s *server) handleOperationCreate() http.HandlerFunc {
	type request struct {
		UserID      int64  `json:"user_id"`
		Barcode     string `json:"barcode"`
		ContainerID int64  `json:"container_id"`
	}
	return func(w http.ResponseWriter, r *http.Request) {
		req := request{}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			s.error(w, http.StatusBadRequest, err)
			return
		}

		var (
			allowedBarcodeList []string
			err                error
		)
		if allowedBarcodeList, err = s.store.Container().GetAllowedBarcodes(req.ContainerID); err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}

		if !helpers.ContainsString(allowedBarcodeList, req.Barcode) {
			s.error(w, http.StatusUnprocessableEntity, errors.New("not allowed barcode: "+req.Barcode))
			return
		}

		operation := &model.Operation{
			UserID:      req.UserID,
			Barcode:     req.Barcode,
			ContainerID: req.ContainerID,
		}

		if err = s.store.Operation().Create(operation); err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}

		s.respond(w, http.StatusCreated, nil)
	}
}

func (s *server) handleGetUserInfo() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userIDStr := r.URL.Query().Get("userId")

		userID, err := strconv.Atoi(userIDStr)
		if err != nil {
			s.error(w, http.StatusBadRequest, err)
			return
		}

		u, err := s.store.User().Find(int64(userID))
		if err != nil {
			s.logger.Info("get user info error: ", err)
			s.error(w, http.StatusInternalServerError, err)
			return
		}
		s.respond(w, http.StatusOK, u)
	}
}

func (s *server) handleGetPartnerList() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		partnerList, err := s.store.Partner().GetPartnerList()
		if err != nil {
			s.logger.Info("get partner list error: ", err)
			s.error(w, http.StatusInternalServerError, err)
			return
		}
		s.respond(w, http.StatusOK, partnerList)
	}
}

func (s *server) authenticateUser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, err := s.sessionsStore.Get(r, sessionsName)
		if err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}

		id, ok := session.Values["userId"]
		if !ok {
			s.error(w, http.StatusUnauthorized, errors.New("not authorized"))
			return
		}

		u, err := s.store.User().Find(id.(int64))
		if err != nil {
			s.logger.Info("authenticateUser error: ", err)
			s.error(w, http.StatusInternalServerError, err)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKeyUser, u)))
	})
}

func (s *server) HandleWhoami() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.respond(w, http.StatusOK, r.Context().Value(ctxKeyUser).(*model.User))
	}
}

func (s *server) SetRequestId(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestId := uuid.New().String()
		w.Header().Set("X-Request-ID", requestId)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKeyRequestId, requestId)))
	})
}

// handleAddBall добавляет бал
func (s *server) handleAddBall() http.HandlerFunc {
	type request struct {
		UserID int64 `json:"user_id"`
	}
	return func(w http.ResponseWriter, r *http.Request) {
		req := request{}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			s.error(w, http.StatusBadRequest, err)
			return
		}
		var err error
		if err = s.store.User().AddBall(req.UserID); err != nil {
			s.error(w, http.StatusInternalServerError, err)
			return
		}
		s.respond(w, http.StatusOK, nil)
	}
}

func (s *server) logRequest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		logger := s.logger.WithFields(logrus.Fields{
			"remote_addr": r.RemoteAddr,
			"requset_id":  r.Context().Value(ctxKeyRequestId),
		})

		logger.Infof("Start %s %s", r.Method, r.RequestURI)

		tStart := time.Now()

		next.ServeHTTP(w, r)

		logger.Infof("Completed %s %s", r.Method, time.Now().Sub(tStart))
	})
}

func (s *server) error(w http.ResponseWriter, code int, err error) {
	s.respond(w, code, map[string]string{"error": err.Error()})
	s.logger.Info("error: ", err)
}

func (s *server) respond(w http.ResponseWriter, code int, data interface{}) {
	w.WriteHeader(code)
	if data != nil {
		if err := json.NewEncoder(w).Encode(data); err != nil {
			s.logger.Info("can't encode data")
		}
	}
}
