import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ContentWidthContainer } from './content-width-container';

describe('ContentWidthContainer', () => {
  let component: ContentWidthContainer;
  let fixture: ComponentFixture<ContentWidthContainer>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ContentWidthContainer]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ContentWidthContainer);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
