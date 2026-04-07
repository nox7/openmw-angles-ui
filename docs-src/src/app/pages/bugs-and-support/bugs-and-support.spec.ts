import { ComponentFixture, TestBed } from '@angular/core/testing';

import { BugsAndSupport } from './bugs-and-support';

describe('BugsAndSupport', () => {
  let component: BugsAndSupport;
  let fixture: ComponentFixture<BugsAndSupport>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BugsAndSupport]
    })
    .compileComponents();

    fixture = TestBed.createComponent(BugsAndSupport);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
