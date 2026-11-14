import { useEffect } from "react";
import { Circle, CircleMarker, MapContainer, Popup, TileLayer, useMap, useMapEvents } from "react-leaflet";
import { Link } from "react-router-dom";
import type { HotspotCluster, MapPoint } from "../../lib/types";
import { priorityMeta, statusMeta } from "../../lib/utils";

const BENGALURU: [number, number] = [12.9716, 77.5946];

const TILE_URL = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';

function FitBounds({ points }: { points: MapPoint[] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length === 0) return;
    if (points.length === 1) {
      map.setView([points[0].latitude, points[0].longitude], 15);
      return;
    }
    const bounds = points.map((point) => [point.latitude, point.longitude] as [number, number]);
    map.fitBounds(bounds, { padding: [32, 32], maxZoom: 15 });
  }, [map, points]);
  return null;
}

export function ComplaintMap({
  points,
  hotspots = [],
  height = 420,
  showHotspots = false,
}: {
  points: MapPoint[];
  hotspots?: HotspotCluster[];
  height?: number;
  showHotspots?: boolean;
}) {
  return (
    <div className="map-shell" style={{ height }}>
      <MapContainer
        center={BENGALURU}
        zoom={12}
        scrollWheelZoom
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer url={TILE_URL} attribution={ATTRIBUTION} />
        <FitBounds points={points} />
        {showHotspots &&
          hotspots.map((hotspot) => (
            <Circle
              key={hotspot.hotspot_id}
              center={[hotspot.centroid.latitude, hotspot.centroid.longitude]}
              radius={Math.max(80, hotspot.radius_meters)}
              pathOptions={{
                color: "#dc2626",
                fillColor: "#dc2626",
                fillOpacity: 0.08,
                weight: 1.5,
              }}
            >
              <Popup>
                <strong>Hotspot {hotspot.hotspot_id}</strong>
                <br />
                {hotspot.total_complaints} complaints · severity {hotspot.severity_tier}
                <br />
                {hotspot.affected_wards.join(", ")}
              </Popup>
            </Circle>
          ))}
        {points.map((point) => {
          const meta = priorityMeta[point.priority] ?? priorityMeta.medium;
          return (
            <CircleMarker
              key={point.id}
              center={[point.latitude, point.longitude]}
              radius={7}
              pathOptions={{
                color: "#ffffff",
                weight: 1.5,
                fillColor: meta.dot,
                fillOpacity: 0.92,
              }}
            >
              <Popup>
                <div className="map-popup">
                  <span className="map-popup__eyebrow">{point.complaint_number}</span>
                  <strong>{point.title}</strong>
                  <span>
                    {statusMeta[point.status]?.label ?? point.status} · {point.ward}
                  </span>
                  <Link to={`/complaints/${point.id}`}>Open complaint →</Link>
                </div>
              </Popup>
            </CircleMarker>
          );
        })}
      </MapContainer>
      {points.length === 0 && (
        <div className="map-empty">No geotagged complaints match the current filters.</div>
      )}
    </div>
  );
}

function ClickHandler({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click(event) {
      onPick(event.latlng.lat, event.latlng.lng);
    },
  });
  return null;
}

export function LocationPickerMap({
  latitude,
  longitude,
  onChange,
  height = 280,
}: {
  latitude?: number | null;
  longitude?: number | null;
  onChange: (lat: number, lng: number) => void;
  height?: number;
}) {
  const hasPoint = typeof latitude === "number" && typeof longitude === "number";
  const center: [number, number] = hasPoint
    ? [latitude as number, longitude as number]
    : BENGALURU;

  return (
    <div className="map-shell" style={{ height }}>
      <MapContainer center={center} zoom={hasPoint ? 16 : 12} style={{ height: "100%", width: "100%" }}>
        <TileLayer url={TILE_URL} attribution={ATTRIBUTION} />
        <ClickHandler onPick={onChange} />
        {hasPoint && (
          <CircleMarker
            center={[latitude as number, longitude as number]}
            radius={9}
            pathOptions={{ color: "#fff", weight: 2, fillColor: "#0e7c66", fillOpacity: 1 }}
          />
        )}
      </MapContainer>
      <div className="map-hint">Click the map to set the exact complaint location</div>
    </div>
  );
}
