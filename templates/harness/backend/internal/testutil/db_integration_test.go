// kit-harness: managed file (the kit's harness-install.sh updates it; local edits are overwritten)

//go:build integration

package testutil

import (
	"context"
	"strings"
	"testing"
)

func TestMigrationsApplied(t *testing.T) {
	pool := NewPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), opTimeout)
	defer cancel()
	var n int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM goose_db_version WHERE is_applied AND version_id > 0").Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n < 1 {
		t.Fatalf("no goose migration applied (count=%d)", n)
	}
}

func TestFixtureLoads(t *testing.T) {
	Load(t, NewPool(t), "00_example")
}

func TestPoolConfigRefusesUnsafeTargets(t *testing.T) {
	tests := []struct {
		name    string
		dsn     string
		wantErr string // empty: accepted
	}{
		{"throwaway database", "postgres://app:app@localhost:5432/app_test_1700000000_42", ""},
		{"loopback ip", "postgres://app:app@127.0.0.1:5432/app_test_1_2", ""},
		{"development database", "postgres://app:app@localhost:5432/app", "refusing database"},
		{"_test_ in the middle", "postgres://app:app@localhost:5432/my_test_app", "refusing database"},
		{"missing run suffix", "postgres://app:app@localhost:5432/app_test_", "refusing database"},
		{"remote host", "postgres://app:app@db.example.com:5432/app_test_1_2", "refusing host"},
		{"remote fallback host", "postgres://app:app@localhost:5432,db.example.com:5432/app_test_1_2", "refusing host"},
		{"unix socket dir", "postgres://app:app@/app_test_1_2?host=/var/run/postgresql", "refusing host"},
		{"not a dsn", "://", "parse DATABASE_URL_TEST"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := poolConfig(tt.dsn)
			if tt.wantErr == "" {
				if err != nil {
					t.Fatalf("poolConfig(%q): %v", tt.dsn, err)
				}
				return
			}
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Fatalf("poolConfig(%q) err = %v, want one containing %q", tt.dsn, err, tt.wantErr)
			}
		})
	}
}
