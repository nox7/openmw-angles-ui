import { Component } from '@angular/core';
import { ContentWidthContainer } from "../../../components/content-width-container/content-width-container";
import { Card } from "../../../components/card/card";
import { CardHeader } from "../../../components/card/card-header/card-header";
import { CardBody } from "../../../components/card/card-body/card-body";
import { DataTable } from "../../../components/data-table/data-table";
import { DtHeader } from "../../../components/data-table/dt-header/dt-header";
import { DtRow } from "../../../components/data-table/dt-row/dt-row";
import { DtCell } from "../../../components/data-table/dt-row/dt-cell/dt-cell";

@Component({
  selector: 'app-widget',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, DataTable, DtHeader, DtRow, DtCell],
  templateUrl: './widget.html',
  styleUrl: './widget.scss',
})
export class Widget {

}
