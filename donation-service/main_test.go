package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"go.opentelemetry.io/otel/attribute"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestHTTPMetricsMiddlewareRecordsStatusAndDuration(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	t.Cleanup(func() {
		if err := provider.Shutdown(context.Background()); err != nil {
			t.Fatalf("erro ao finalizar MeterProvider: %v", err)
		}
	})

	httpMetrics, err := newHTTPMetrics(provider.Meter("test"))
	if err != nil {
		t.Fatalf("erro ao criar métricas: %v", err)
	}

	handler := httpMetrics.Middleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusCreated)
	}))
	request := httptest.NewRequest(http.MethodPost, "/donations", nil)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	var collected metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &collected); err != nil {
		t.Fatalf("erro ao coletar métricas: %v", err)
	}

	var foundRequests, foundDuration bool
	for _, scope := range collected.ScopeMetrics {
		for _, measured := range scope.Metrics {
			switch measured.Name {
			case "donation.http.server.requests":
				sum, ok := measured.Data.(metricdata.Sum[int64])
				if !ok || len(sum.DataPoints) != 1 || sum.DataPoints[0].Value != 1 {
					t.Fatalf("contador de requisições inesperado: %#v", measured.Data)
				}
				attrs := sum.DataPoints[0].Attributes
				assertAttribute(t, attrs, "http.request.method", "POST")
				assertAttribute(t, attrs, "http.route", "/donations")
				assertAttribute(t, attrs, "http.response.status_code", "201")
				foundRequests = true
			case "donation.http.server.request.duration":
				histogram, ok := measured.Data.(metricdata.Histogram[float64])
				if !ok || len(histogram.DataPoints) != 1 || histogram.DataPoints[0].Count != 1 {
					t.Fatalf("histograma de duração inesperado: %#v", measured.Data)
				}
				foundDuration = true
			}
		}
	}

	if !foundRequests || !foundDuration {
		t.Fatalf("métricas ausentes: requests=%t duration=%t", foundRequests, foundDuration)
	}
}

func assertAttribute(t *testing.T, attrs attribute.Set, key, expected string) {
	t.Helper()
	value, ok := attrs.Value(attribute.Key(key))
	if !ok || value.AsString() != expected {
		t.Fatalf("atributo %s: obtido %q, esperado %q", key, value.AsString(), expected)
	}
}
