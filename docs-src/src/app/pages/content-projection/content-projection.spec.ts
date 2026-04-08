import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ContentProjection } from './content-projection';

describe('ContentProjection', () => {
  let component: ContentProjection;
  let fixture: ComponentFixture<ContentProjection>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ContentProjection]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ContentProjection);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
