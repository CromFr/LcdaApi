import {Component, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {RouteParams}       from "angular2/router";

import {CharsService}   from "./chars.service";


@Component({
    selector:    "chardetails",
    templateUrl: "app/chars/details.component.html",
    directives:  [],
    providers:   [HTTP_PROVIDERS, CharsService]
})
export class CharDetailsComponent implements OnInit {
    constructor(private _charsService: CharsService, private _routeParams: RouteParams) { }


    ngOnInit() {
        this._charsService.getChar(this._routeParams.get("account"), this._routeParams.get("char"))
            .subscribe(
              c => { this.character = c; console.log(c); },
              error => this.errorMsg = <any>error);
    }
    public errorMsg: string;
    public character: any;

    abilityModifier(value: number) {
        return Math.floor(value / 2) - 5;
    }

}