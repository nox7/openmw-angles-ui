import { Component, inject } from '@angular/core';
import { ContentWidthContainer } from "../../../components/content-width-container/content-width-container";
import { Card } from "../../../components/card/card";
import { CardHeader } from "../../../components/card/card-header/card-header";
import { CardBody } from "../../../components/card/card-body/card-body";
import { DataTable } from "../../../components/data-table/data-table";
import { DtHeader } from "../../../components/data-table/dt-header/dt-header";
import { DtRow } from "../../../components/data-table/dt-row/dt-row";
import { DtCell } from "../../../components/data-table/dt-row/dt-cell/dt-cell";
import { Alert } from "../../../components/alert/alert";
import { GetCommonCSSProperties } from '../CommonProperties';
import { DomSanitizer } from '@angular/platform-browser';

@Component({
  selector: 'app-text',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, DataTable, DtHeader, DtRow, DtCell, Alert],
  templateUrl: './text.html',
  styleUrl: './text.scss',
})
export class Text {
  public CommonCSSProperties = GetCommonCSSProperties(inject(DomSanitizer), ["padding"]);
}
