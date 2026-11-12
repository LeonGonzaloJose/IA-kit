// kit-harness: managed file (the kit's harness-install.sh updates it; local edits are overwritten)

//go:build integration

// Package testutil is the integration harness: a pool on the throwaway database created by `make test-integration`.
package testutil

import (
	"context"
	"embed"
	"fmt"
	"os"
	"regexp"
	"slices"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

const opTimeout = 10 * time.Second

//go:embed fixtures/*.sql
var fixtures embed.FS

var testDBName = regexp.MustCompile(`_test_\d+_\d+$`)

// poolConfig refuses anything but a throwaway database on this machine, so the harness can never
// touch development or remote data.
func poolConfig(dsn string) (*pgxpool.Config, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL_TEST: %w", err)
	}
	if db := cfg.ConnConfig.Database; !testDBName.MatchString(db) {
		return nil, fmt.Errorf("refusing database %q: name must end in _test_<n>_<n>", db)
	}
	hosts := []string{cfg.ConnConfig.Host}
	for _, fb := range cfg.ConnConfig.Fallbacks { // multi-host DSNs and TLS fallbacks
		hosts = append(hosts, fb.Host)
	}
	for _, host := range hosts {
		if !slices.Contains([]string{"localhost", "127.0.0.1", "::1"}, host) {
			return nil, fmt.Errorf("refusing host %q: the harness only runs against a local Postgres", host)
		}
	}
	cfg.ConnConfig.ConnectTimeout = 5 * time.Second
	cfg.MaxConns = 4 // packages run in parallel, each with its own pool
	return cfg, nil
}

func NewPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL_TEST")
	if dsn == "" {
		t.Fatal("DATABASE_URL_TEST is not set: run `make test-integration`")
	}
	cfg, err := poolConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), opTimeout)
	defer cancel()
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)
	// pgxpool connects lazily: without the ping a dead server would hang the first query instead
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return pool
}

// Load runs fixtures/<name>.sql (keep fixtures idempotent: tests in a run share one database).
func Load(t *testing.T, pool *pgxpool.Pool, name string) {
	t.Helper()
	sql, err := fixtures.ReadFile("fixtures/" + name + ".sql")
	if err != nil {
		t.Fatalf("fixture %q: %v", name, err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), opTimeout)
	defer cancel()
	if _, err := pool.Exec(ctx, string(sql)); err != nil {
		t.Fatalf("load fixture %q: %v", name, err)
	}
}
