import { Link } from "react-router-dom";

export function Home() {
  return (
    <div>
      <h2>Workbench</h2>
      <Link to="/docs" style={{ fontSize: "1.1rem" }}>
        Documents →
      </Link>
    </div>
  );
}
