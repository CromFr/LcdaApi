import "./vendor";
import {provide} from "angular2/core";
import {bootstrap} from "angular2/platform/browser";
import {ROUTER_PROVIDERS, LocationStrategy, PathLocationStrategy} from "angular2/router";
import {HTTP_PROVIDERS} from "angular2/http";


import {AppComponent} from "./app.component";

document.addEventListener("DOMContentLoaded", function main() {
  bootstrap(AppComponent, [
    ...HTTP_PROVIDERS,
    ...ROUTER_PROVIDERS,
    provide(LocationStrategy, { useClass: PathLocationStrategy })
  ])
  .catch(err => console.error(err));
});