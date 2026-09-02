(() => {
  const body = document.body;
  const source = body.dataset.policySource;
  const content = document.getElementById("policy-content");
  const status = document.getElementById("policy-status");

  if (!source || !content || !status) {
    return;
  }

  fetch(source, {credentials: "same-origin"})
    .then((response) => {
      if (!response.ok) {
        throw new Error("Policy document could not be loaded.");
      }
      return response.text();
    })
    .then((text) => {
      content.textContent = text;
      content.hidden = false;
      status.hidden = true;
    })
    .catch(() => {
      status.textContent =
        "The document could not be loaded. Use the plain-text document link below.";
    });
})();
