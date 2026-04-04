---
name: Don't minimize scope
description: Stop defaulting to "skip" or "pre-existing" — fix things properly when they're in scope
type: feedback
---

Ne pas minimiser systématiquement le scope des fixes en classant trop vite en "pré-existant", "pas le bon moment", ou "low value". Quand du code est ouvert et qu'un problème est identifié, le traiter. Le biais de conservation (protéger le contexte court plutôt que la qualité) est frustrant pour l'utilisateur.

**Why:** L'utilisateur veut du travail approfondi, pas un tri rapide qui reporte tout. Classer en "skip" sans examiner sérieusement donne l'impression de paresse.

**How to apply:** Quand un agent de review remonte un problème, l'examiner sérieusement. Si c'est dans le périmètre du travail en cours (même fichier, même module, même concern), le traiter. Ne skipper que ce qui est réellement hors scope ou un faux positif démontrable.
