import {Component, AfterViewInit} from "angular2/core";

import {CharListComponent} from "./charlist.component";

declare var $: any;

@Component({
    selector:    "app",
    directives:  [CharListComponent],
    templateUrl: "app/app.component.html",
})
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