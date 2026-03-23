import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Layout } from "./components/Layout";
import { CrudList, CrudDetail } from "./components/CrudPage";
import { DocumentView } from "./pages/DocumentView";
import { Home } from "./pages/Home";
import "./index.css";

// Module entities — defines what entities each module exposes
const modules: Record<string, string[]> = {
  docs: ["document", "charte", "library"],
  crm: ["client", "interaction"],
  quote: ["devis", "facture"],
  project: ["project", "phase"],
  planning: ["event"],
  stock: ["article", "movement"],
  purchase: ["order_header"],
  catalog: ["article"],
  ledger: ["entry"],
  expense: ["note"],
  hr: ["employee"],
  asset: ["asset"],
};

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Home />} />

          {/* Custom pages */}
          <Route path="/docs/document/:slug" element={<DocumentView />} />

          {/* Generic CRUD pages for all modules */}
          {Object.entries(modules).map(([schema, entities]) =>
            entities.map((entity) => [
              <Route
                key={`${schema}-${entity}-list`}
                path={`/${schema}/${entity}`}
                element={<CrudList schema={schema} entity={entity} />}
              />,
              <Route
                key={`${schema}-${entity}-detail`}
                path={`/${schema}/${entity}/:slug`}
                element={<CrudDetail schema={schema} entity={entity} />}
              />,
            ])
          )}

          {/* Module index → redirect to first entity */}
          {Object.entries(modules).map(([schema, entities]) => (
            <Route
              key={`${schema}-index`}
              path={`/${schema}`}
              element={<CrudList schema={schema} entity={entities[0]} />}
            />
          ))}
        </Route>
      </Routes>
    </BrowserRouter>
  </StrictMode>
);
