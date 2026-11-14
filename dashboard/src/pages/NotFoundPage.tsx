import { Link } from "react-router-dom";
import { ArrowLeft, Compass } from "lucide-react";
import { BrandMark } from "../components/layout/BrandMark";

export function NotFoundPage() {
  return (
    <div className="notfound">
      <BrandMark size={44} />
      <p className="page-header__eyebrow">404 · Route not found</p>
      <h1>This page is off the map</h1>
      <p>
        The address you opened does not exist in the CivicAI console. It may have been moved, or
        you may not have access to it.
      </p>
      <div className="notfound__actions">
        <Link to="/" className="btn btn--primary btn--md">
          <Compass size={16} /> Go to overview
        </Link>
        <Link to="/complaints" className="btn btn--outline btn--md">
          <ArrowLeft size={16} /> Complaint queue
        </Link>
      </div>
    </div>
  );
}
