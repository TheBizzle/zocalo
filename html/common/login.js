window.addEventListener("load", () => {

  const token = localStorage.getItem("vlgallery.auth-token");

  if (token === null || token === "") {
    document.getElementById("not-logged-in-pane").classList.remove("hidden");
  } else {

    fetch(`/auth/is-logged-in/${token}`, {
      method:  "GET"
    }).then((res) => res.text().then((text) => [res.ok, text])).then(
      ([isOK, text]) => {
        if (isOK) {
          const id = (text === "1") ? "logged-in-pane" : "not-logged-in-pane";
          document.getElementById(id).classList.remove("hidden");
        } else {
          alert(text);
        }
      }
    );

  }

});

document.getElementById("main-form").addEventListener("submit", (e) => {

  e.preventDefault();

  sessionStorage.setItem("vlgallery.email", e.target.email.value);

  fetch("/auth/request-otp", {
    method:   "POST"
  , redirect: "follow"
  , headers:  { "Content-Type": "application/x-www-form-urlencoded" }
  , body:     new URLSearchParams(new FormData(e.target))
  }).then(
    (res) => {
      if (res.redirected) {
        window.location.href = res.url;
      } else {
        return res.text().then((text) => [res.ok, text]);
      }
    }
  ).then(
    ([isOK, text]) => {
      if (isOK) {
        debugger
        document.body.innerText = text;
      } else {
        alert(text);
      }
    }
  );

  return false;

});

document.getElementById("logout-button").addEventListener("click", () => {

  const params = new URLSearchParams();
  params.append("login-token", localStorage.getItem("vlgallery.auth-token"));

  fetch("/auth/logout", {
    method:  "POST"
  , headers: { "Content-Type": "application/x-www-form-urlencoded" }
  , body:    params
  }).then((res) => res.text().then((text) => [res.ok, text])).then(
    ([isOK, text]) => {
      if (isOK) {
        localStorage.removeItem("vlgallery.auth-token");
        window.location.reload();
      } else {
        alert(text);
      }
    }
  );

});
