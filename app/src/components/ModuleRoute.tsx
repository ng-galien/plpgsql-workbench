import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { useStore } from "../lib/store";
import { get } from "../lib/api";
import { CrudList, CrudDetail } from "./CrudPage";
import { SduiRenderer } from "./SduiRenderer";

/** Resolve entity from store based on URL params */
function useEntity() {
  const { schema, route } = useParams<{ schema: string; route: string }>();
  const modules = useStore((s) => s.modules);
  const loading = useStore((s) => s.loading);

  if (loading || !schema) return { loading: true, schema, route, entity: undefined };

  const mod = modules.find((m) => m.schema === schema);
  if (!mod) return { loading: false, schema, route, entity: undefined };

  // Match by href first, then fallback to entity name
  const item = mod.items.find(
    (i) => i.href?.replace(/^\//, "") === route && i.entity
  ) ?? mod.items.find(
    (i) => i.entity === route
  );

  return { loading: false, schema, route, entity: item?.entity };
}

/** Hook: fetch route_crud and check for SDUI */
function useSdui(schema: string | undefined, entity: string | undefined, slug?: string) {
  const [sdui, setSdui] = useState<{ ui: unknown; datasources: unknown } | null>(null);
  const [checked, setChecked] = useState(false);

  const uri = schema && entity
    ? slug ? `${schema}://${entity}/${slug}` : `${schema}://${entity}`
    : undefined;

  useEffect(() => {
    if (!uri) return;
    get(uri)
      .then((res) => {
        if (res?.ui) {
          setSdui({ ui: res.ui, datasources: res.datasources });
        }
      })
      .catch(() => {})
      .finally(() => setChecked(true));
  }, [uri]);

  return { sdui, checked };
}

/** /:schema/:route — list page */
export function ModuleRoute() {
  const { loading, schema, route, entity } = useEntity();
  const { sdui, checked } = useSdui(schema, entity);

  if (loading || !checked) return <p>Chargement...</p>;
  if (!entity || !schema) return <p>Page introuvable.</p>;

  if (sdui) {
    return (
      <SduiRenderer
        ui={sdui.ui as any}
        datasources={sdui.datasources as any}
      />
    );
  }

  return <CrudList schema={schema} entity={entity} route={route} />;
}

/** /:schema/:route/:slug — detail page */
export function ModuleRouteDetail() {
  const { slug } = useParams<{ slug: string }>();
  const { loading, schema, route, entity } = useEntity();
  const { sdui, checked } = useSdui(schema, entity, slug);

  if (loading || !checked) return <p>Chargement...</p>;
  if (!entity || !schema) return <p>Page introuvable.</p>;

  if (sdui) {
    return (
      <SduiRenderer
        ui={sdui.ui as any}
        datasources={sdui.datasources as any}
      />
    );
  }

  return <CrudDetail schema={schema} entity={entity} route={route} />;
}

/** /:schema — module index, redirect to first entity */
export function ModuleIndex() {
  const { schema } = useParams<{ schema: string }>();
  const modules = useStore((s) => s.modules);
  const loading = useStore((s) => s.loading);
  const first = !loading
    ? modules.find((m) => m.schema === schema)?.items.find((i) => i.entity)
    : undefined;
  const { sdui, checked } = useSdui(schema, first?.entity);

  if (loading || !checked) return <p>Chargement...</p>;

  const mod = modules.find((m) => m.schema === schema);
  if (!mod) return <p>Module introuvable.</p>;
  if (!first || !schema) return <p>Aucune entité.</p>;

  if (sdui) {
    return (
      <SduiRenderer
        ui={sdui.ui as any}
        datasources={sdui.datasources as any}
      />
    );
  }

  const route = first.href?.replace(/^\//, "");
  return <CrudList schema={schema} entity={first.entity!} route={route} />;
}
