import "es6-shim";
import "es6-promise";
import "zone.js/dist/zone";
import "reflect-metadata";
import "@angular/compiler";
import "@angular/platform-browser";
import {enableProdMode} from "@angular/core";

// RxJS
import "rxjs";

// Materialize
import "jquery";
import "hammerjs";
import "materialize-css";
import "angular2-materialize";
import "materialize-css";

if ("production" === "BRUNCH_ENVIRONMENT") {
  enableProdMode();
}
