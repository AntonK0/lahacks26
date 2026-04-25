exports = async function(request, response) {
  const body = parseJsonBody(request);

  const queryVector = body.queryVector;
  if (!Array.isArray(queryVector) || queryVector.length !== 768) {
    return sendJson(response, 400, {
      error: "queryVector must be an array with 768 numeric values."
    });
  }

  const normalizedVector = queryVector.map((value) => Number(value));
  if (normalizedVector.some((value) => !Number.isFinite(value))) {
    return sendJson(response, 400, {
      error: "queryVector contains non-numeric values."
    });
  }

  const dbName = context.values.get("MONGODB_DB") || "lahacks";
  const defaultCollection = context.values.get("MONGODB_COLLECTION") || "textbook_chunks";
  const defaultIndex = context.values.get("MONGODB_VECTOR_INDEX") || "textbook_chunks_vector_index";
  const collectionName = defaultCollection;
  const indexName = body.index || defaultIndex;
  const limit = clampInteger(body.limit, 1, 10, 5);
  const numCandidates = clampInteger(body.numCandidates, limit, 200, Math.max(limit * 10, 50));
  const isbn = normalizeRequiredString(body.isbn);

  if (!isbn) {
    return sendJson(response, 400, {
      error: "isbn is required for scoped textbook retrieval."
    });
  }

  if (!isAllowedCollection(collectionName, defaultCollection)) {
    return sendJson(response, 400, {
      error: "Requested collection is not allowed."
    });
  }

  const filter = { isbn };
  if (typeof body.textbook_id === "string" && body.textbook_id.length > 0) {
    filter.textbook_id = body.textbook_id;
  }

  const collection = context.services
    .get("mongodb-atlas")
    .db(dbName)
    .collection(collectionName);

  const vectorSearch = {
    index: indexName,
    path: "embedding",
    queryVector: normalizedVector,
    numCandidates,
    limit,
    filter
  };

  const results = await collection
    .aggregate([
      {
        $vectorSearch: vectorSearch
      },
      {
        $project: {
          _id: 0,
          text: 1,
          textbook_id: 1,
          isbn: 1,
          source_file: 1,
          page: 1,
          chunk_index: 1,
          score: { $meta: "vectorSearchScore" }
        }
      }
    ])
    .toArray();

  return sendJson(response, 200, {
    collection: collectionName,
    index: indexName,
    isbn,
    count: results.length,
    chunks: results
  });
};

function parseJsonBody(request) {
  if (!request || !request.body) {
    return {};
  }

  const text = request.body.text();
  if (!text) {
    return {};
  }

  return JSON.parse(text);
}

function sendJson(response, statusCode, body) {
  if (response) {
    response.setStatusCode(statusCode);
    response.setHeader("Content-Type", "application/json");
    response.setBody(JSON.stringify(body));
    return;
  }

  return body;
}

function clampInteger(value, min, max, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}

function normalizeRequiredString(value) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function isAllowedCollection(collectionName, defaultCollection) {
  if (!/^[A-Za-z0-9_-]+$/.test(collectionName)) {
    return false;
  }

  const configured = context.values.get("ALLOWED_COLLECTIONS");
  const allowed = configured
    ? configured.split(",").map((value) => value.trim()).filter(Boolean)
    : [defaultCollection];

  return allowed.includes(collectionName);
}
