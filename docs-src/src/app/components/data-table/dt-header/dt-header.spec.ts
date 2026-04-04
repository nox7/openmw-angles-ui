import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DtHeader } from './dt-header';

describe('DtHeader', () => {
  let component: DtHeader;
  let fixture: ComponentFixture<DtHeader>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DtHeader]
    })
    .compileComponents();

    fixture = TestBed.createComponent(DtHeader);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
