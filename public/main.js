const { hash } = window.location;

const baseUrlApi = "http://127.0.0.1:56779";

const index = document.querySelector("#index");
const code = document.querySelector("#code");

const codeTitle = document.querySelector("#code-title");
const codeBody = document.querySelector("#code-body");

const inputCode = document.querySelector("#input-code");
const inputName = document.querySelector("#input-name");
const inputLanguage = document.querySelector("#input-language");
const inputExpiration = document.querySelector("#input-expiration");
const submit = document.querySelector("#submit");

if (hash) {
  index.style.display = "none";
  code.style.display = "block";

  fetch(`${baseUrlApi}/${hash.slice(1)}/`).then((res) => {
    res.json().then((data) => {
      const { name, code, language } = data;

      codeTitle.innerHTML = name;
      codeBody.innerHTML = code;

      codeBody.classList.add(`language-${language}`);

      hljs.highlightAll();
    });
  });
}

submit.addEventListener("click", () => {
  fetch(`${baseUrlApi}/`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      code: inputCode.value,
      name: inputName.value,
      language: inputLanguage.value,
      inputExpiration: inputExpiration.value,
    }),
  }).then((res) => {
    res.json().then((data) => {
      const { id } = data;

      window.location.href += `#${id}`;
      window.location.reload();
    });
  });
});
