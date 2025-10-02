package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
)

type UserStats struct {
	Username      string `json:"username"`
	PostCount     int    `json:"post_count"`
	LastPostTitle string `json:"last_post_title"`
}

type Config struct {
	DBHost      string
	DBPort      string
	DBUser      string
	DBPassword  string
	DBName      string
	TablePrefix string
}

var config Config
var db *sql.DB

func main() {
	// Load configuration from environment variables
	config = Config{
		DBHost:      getEnv("DB_HOST", "localhost"),
		DBPort:      getEnv("DB_PORT", "3306"),
		DBUser:      getEnv("DB_USER", "root"),
		DBPassword:  getEnv("DB_PASSWORD", ""),
		DBName:      getEnv("DB_NAME", "wordpress"),
		TablePrefix: getEnv("DB_TABLE_PREFIX", "wp_"),
	}

	// Initialize database connection
	var err error
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true",
		config.DBUser, config.DBPassword, config.DBHost, config.DBPort, config.DBName)

	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	log.Println("Database connection established")

	// Setup routes
	http.HandleFunc("/api/userinfo", userInfoHandler)

	// Start server
	port := getEnv("PORT", "8080")
	log.Printf("Starting server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func userInfoHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	username := r.URL.Query().Get("user")

	stats, err := getUserStats(username)
	if err != nil {
		log.Printf("Error getting user stats: %v", err)
		http.Error(w, fmt.Sprintf("Error: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(stats); err != nil {
		log.Printf("Error encoding JSON: %v", err)
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
		return
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getUserStats(username string) ([]UserStats, error) {
	query := fmt.Sprintf(`
		SELECT
			u.user_login as username,
			COUNT(p.ID) as post_count,
			COALESCE(
				(SELECT post_title
				 FROM %sposts
				 WHERE post_author = u.ID
				   AND post_status = 'publish'
				   AND post_type = 'post'
				 ORDER BY post_date DESC
				 LIMIT 1),
				''
			) as last_post_title
		FROM %susers u
		LEFT JOIN %sposts p ON u.ID = p.post_author
			AND p.post_status = 'publish'
			AND p.post_type = 'post'
	`, config.TablePrefix, config.TablePrefix, config.TablePrefix)

	if username != "" {
		query += " WHERE u.user_login = ?"
	}

	query += " GROUP BY u.ID, u.user_login ORDER BY post_count DESC"

	var rows *sql.Rows
	var err error
	if username != "" {
		rows, err = db.Query(query, username)
	} else {
		rows, err = db.Query(query)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}
	defer rows.Close()

	var stats []UserStats
	for rows.Next() {
		var stat UserStats
		if err := rows.Scan(&stat.Username, &stat.PostCount, &stat.LastPostTitle); err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		stats = append(stats, stat)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %w", err)
	}

	return stats, nil
}
