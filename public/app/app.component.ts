import {Component, AfterViewInit} from "angular2/core";
import {RouteConfig, ROUTER_DIRECTIVES, ROUTER_PROVIDERS} from "angular2/router";

import {CharsService}   from "./chars/chars.service";
import {CharListComponent} from "./chars/list.component";
import {CharDetailsComponent} from "./chars/details.component";

declare var $: any;

@Component({
    selector:    "app",
    directives:  [ROUTER_DIRECTIVES],
    providers: [
        ROUTER_PROVIDERS,
        CharsService
    ],
    templateUrl: "app/app.component.html",
})
@RouteConfig([
  {path: "/:account/chars", name: "CharList", component: CharListComponent}, // useAsDefault: true
  {path: "/:account/chars/:char", name: "CharDetails", component: CharDetailsComponent}
])
export class AppComponent implements AfterViewInit {
    public isLoggedIn: boolean = false;
    public account: string;



    ngAfterViewInit() {
        if (!this.materializeInit) {
            this.materializeInit = true;
            $("#modal-login-button").leanModal();
            $("#sidebar-button").sideNav();
        }
    }

    private materializeInit: boolean = false;
}