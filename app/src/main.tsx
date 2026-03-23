import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Layout } from "./components/Layout";
import { DocumentList } from "./pages/DocumentList";
import { DocumentView } from "./pages/DocumentView";
import { Home } from "./pages/Home";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Home />} />
          <Route path="/docs" element={<DocumentList />} />
          <Route path="/docs/:slug" element={<DocumentView />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </StrictMode>
);
