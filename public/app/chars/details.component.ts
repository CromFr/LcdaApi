import {Component, Input, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {RouteParams, RouteData} from "angular2/router";

import {CharsService}   from "./chars.service";


@Component({
    selector:    "chardetails",
    templateUrl: "app/chars/details.component.html",
    directives:  [],
    providers:   [HTTP_PROVIDERS, CharsService]
})
export class CharDetailsComponent implements OnInit {
    constructor(private _charsService: CharsService, private _data: RouteData, private _routeParams: RouteParams) {
        let deleted: boolean = _data.get("deleted");
        if (deleted != null && deleted === true)
            this.isDeletedChar = true;
    }

    private isDeletedChar: boolean = false;


    ngOnInit() {
        this._charsService.getChar(this._routeParams.get("account"), this._routeParams.get("char"), this.isDeletedChar)
            .subscribe(
              c => this.character = c,
              error => this.errorMsg = <any>error);
    }
    public errorMsg: string;
    public character: any;

    abilityModifier(value: number) {
        return Math.floor(value / 2) - 5;
    }

}