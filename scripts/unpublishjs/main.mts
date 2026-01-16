process.env.MU_SPARQL_ENDPOINT = 'http://virtuoso:8890/sparql';
process.env.LOG_SPARQL_ALL = 'true';
process.env.DEBUG_AUTH_HEADERS = 'false';
const authSudo = await import('@lblod/mu-auth-sudo');
const { querySudo } = authSudo;

async function doQuery() {
  const testQuery = `
  SELECT * WHERE { ?s ?p ?v } LIMIT 10
  `;
  const result = await querySudo(testQuery);
  console.log('result', JSON.stringify(result, undefined, 2));
}

await doQuery();
