window.addEventListener("load", (e) => {
  document.getElementById("email-address").innerText = sessionStorage.getItem("vlgallery.email");
});

document.getElementById("main-form").addEventListener("submit", (e) => {

  e.preventDefault();

  const params = new URLSearchParams(new FormData(e.target));
  params.append("email", sessionStorage.getItem("vlgallery.email"));

  fetch("/auth/input-otp", {
    method:  "POST"
  , headers: { "Content-Type": "application/x-www-form-urlencoded" }
  , body:    params
  }).then(
    (res) => res.text().then((text) => [res.ok, text])
  ).then(
    ([isOK, text]) => {
      if (isOK) {
        sessionStorage.removeItem("vlgallery.email");
        localStorage.setItem("vlgallery.auth-token", text);
        window.location.href = localStorage.getItem("vlgallery.breadcrumb");
      } else {
        alert(text);
      }
    }
  );

  return false;

});
