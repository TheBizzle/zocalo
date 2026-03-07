document.getElementById("main-form").addEventListener("submit", (e) => {

  e.preventDefault();

  fetch("/auth/register", {
    method:  "POST"
  , headers: { "Content-Type": "application/x-www-form-urlencoded" }
  , body:    new URLSearchParams(new FormData(e.target))
  }).then(
    (res) => {
      if (res.ok) {
        window.location.href = localStorage.getItem("vlgallery.breadcrumb");
      }
      return res.text().then((text) => [res.ok, text]);
    }
  ).then(
    ([isOK, text]) => {
      if (!isOK) {
        alert(text);
      }
    }
  );

  return false;

});
