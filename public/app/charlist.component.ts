import {Component, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";

import {CharListService}   from "./charlist.service";

interface Character {
    name: string;
}

@Component({
    selector:    "charlist",
    templateUrl: "app/charlist.component.html",
    directives:  [], // components inside this one
    providers:   [
        HTTP_PROVIDERS,
        CharListService
    ]
})
export class CharListComponent implements OnInit {
    constructor(private _charListService: CharListService) { }

    ngOnInit() {
        this._charListService.getList()
            .subscribe(
              list => {
                this.activeChars = list[0];
                this.deletedChars = list[1];
              },
              error => this.errorMsg = <any>error);
    }

    public errorMsg: string;


    public activeChars: Character[];
    public deletedChars: Character[];
}